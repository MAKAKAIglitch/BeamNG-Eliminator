-- Server-authoritative match lifecycle coordinator.
-- This module owns phase transitions and composes the pure roster model.
-- It intentionally does not call undocumented vehicle-spawn/AI APIs.

local RosterManager = require("modules.roster_manager")
local MatchManager = {}

local PHASE = {
    WAITING = "waiting",
    LOBBY = "lobby",
    STARTING = "starting",
    ACTIVE = "active",
    FINAL_SHOWDOWN = "final_showdown",
    FINISHED = "finished",
    STOPPED = "stopped"
}

MatchManager.PHASE = PHASE

local state = {
    phase = PHASE.WAITING,
    match_id = nil,
    roster = nil,
    player_names = {},
    winner_id = nil,
    stop_reason = nil
}

local config = {
    competitor_limit = RosterManager.CAPACITY,
    minimum_human_players = 1,
    fill_open_slots_with_ai = true,
    ai_id_prefix = "ai:"
}

local function valid_id(value)
    return type(value) == "string" and value ~= ""
end

-- BeamMP runtime player IDs are numeric. Convert them to an internal,
-- match-scoped string ID before passing them to the roster model.
local function normalize_player_id(value)
    if type(value) == "number" and value >= 0 and value % 1 == 0 then
        return "player:" .. tostring(value)
    end
    if valid_id(value) then
        return value
    end
    return nil
end

local function transition(expected_phase, next_phase)
    if state.phase ~= expected_phase then
        return false, "invalid_phase:" .. state.phase
    end
    state.phase = next_phase
    return true
end

local function active_competitor_exists(competitor_id)
    if not state.roster then
        return false
    end
    for _, slot in ipairs(state.roster.slots) do
        if slot.competitor_id == competitor_id and slot.status == "active" then
            return true
        end
    end
    return false
end

function MatchManager.initialize(options)
    options = options or {}
    local requested_capacity = options.competitor_limit or RosterManager.CAPACITY
    local minimum_humans = options.minimum_human_players or 1
    local fill_ai = options.fill_open_slots_with_ai
    if fill_ai == nil then
        fill_ai = true
    end

    if type(requested_capacity) ~= "number"
        or requested_capacity < 1
        or requested_capacity % 1 ~= 0
        or requested_capacity > RosterManager.CAPACITY then
        return false, "invalid_competitor_limit"
    end
    if type(minimum_humans) ~= "number"
        or minimum_humans < 1
        or minimum_humans % 1 ~= 0
        or minimum_humans > requested_capacity then
        return false, "invalid_minimum_human_players"
    end
    if type(fill_ai) ~= "boolean" then
        return false, "invalid_fill_open_slots_with_ai"
    end

    local ai_prefix = options.ai_id_prefix or "ai:"
    if not valid_id(ai_prefix) then
        return false, "invalid_ai_id_prefix"
    end

    config.competitor_limit = requested_capacity
    config.minimum_human_players = minimum_humans
    config.fill_open_slots_with_ai = fill_ai
    config.ai_id_prefix = ai_prefix

    state = {
        phase = PHASE.WAITING,
        match_id = nil,
        roster = nil,
        player_names = {},
        winner_id = nil,
        stop_reason = nil
    }
    return true
end

function MatchManager.create_lobby(match_id)
    if state.phase ~= PHASE.WAITING and state.phase ~= PHASE.FINISHED
        and state.phase ~= PHASE.STOPPED then
        return false, "match_already_in_progress"
    end
    if not valid_id(match_id) then
        return false, "invalid_match_id"
    end

    state = {
        phase = PHASE.LOBBY,
        match_id = match_id,
        roster = RosterManager.create_empty_roster(config.competitor_limit),
        player_names = {},
        winner_id = nil,
        stop_reason = nil
    }
    return true, MatchManager.snapshot()
end

function MatchManager.add_player(player_id, display_name)
    local competitor_id = normalize_player_id(player_id)
    if not competitor_id then
        return false, "invalid_player_id"
    end

    if state.phase == PHASE.LOBBY then
        local ok, slot_or_reason = RosterManager.add_human(state.roster, competitor_id)
        if not ok then
            return false, slot_or_reason
        end
        state.player_names[competitor_id] =
            type(display_name) == "string" and display_name ~= ""
            and display_name or competitor_id
        return true, {
            role = "competitor",
            slot = slot_or_reason,
            competitor_id = competitor_id,
            snapshot = MatchManager.snapshot()
        }
    end

    if state.phase == PHASE.STARTING or state.phase == PHASE.ACTIVE
        or state.phase == PHASE.FINAL_SHOWDOWN then
        local ok, result = RosterManager.add_late_joiner(state.roster, competitor_id)
        if not ok then
            return false, result
        end
        return true, {
            role = "spectator",
            competitor_id = competitor_id,
            status = result,
            snapshot = MatchManager.snapshot()
        }
    end

    return false, "match_not_accepting_players"
end

function MatchManager.lock_roster()
    local ok, reason = transition(PHASE.LOBBY, PHASE.STARTING)
    if not ok then
        return false, reason
    end

    if config.fill_open_slots_with_ai then
        local filled, result = RosterManager.lock_and_fill_ai(
            state.roster,
            config.ai_id_prefix,
            config.minimum_human_players
        )
        if not filled then
            state.phase = PHASE.LOBBY
            return false, result
        end
        return true, {
            ai_added = result,
            snapshot = MatchManager.snapshot()
        }
    end

    local human_count = 0
    for _, slot in ipairs(state.roster.slots) do
        if slot.kind == "human" and slot.status == "active" then
            human_count = human_count + 1
        end
    end
    if human_count < config.minimum_human_players then
        state.phase = PHASE.LOBBY
        return false, "minimum_humans_not_met"
    end

    state.roster.locked = true
    return true, {
        ai_added = 0,
        snapshot = MatchManager.snapshot()
    }
end

function MatchManager.start_match()
    return transition(PHASE.STARTING, PHASE.ACTIVE)
end

function MatchManager.begin_final_showdown()
    if state.phase ~= PHASE.ACTIVE then
        return false, "invalid_phase:" .. state.phase
    end
    if RosterManager.count_active(state.roster) < 2 then
        return false, "not_enough_competitors"
    end
    state.phase = PHASE.FINAL_SHOWDOWN
    return true
end

function MatchManager.eliminate(competitor_id, reason)
    if state.phase ~= PHASE.ACTIVE and state.phase ~= PHASE.FINAL_SHOWDOWN then
        return false, "match_not_active"
    end
    local ok, slot_or_reason = RosterManager.eliminate(
        state.roster,
        competitor_id,
        reason
    )
    if not ok then
        return false, slot_or_reason
    end
    return true, {
        slot = slot_or_reason,
        active_competitors = RosterManager.count_active(state.roster)
    }
end

function MatchManager.finish(winner_id)
    if state.phase ~= PHASE.FINAL_SHOWDOWN then
        return false, "final_showdown_not_active"
    end
    if not active_competitor_exists(winner_id) then
        return false, "winner_not_active"
    end
    state.winner_id = winner_id
    state.phase = PHASE.FINISHED
    return true, MatchManager.snapshot()
end

function MatchManager.stop(reason)
    if state.phase == PHASE.WAITING or state.phase == PHASE.FINISHED
        or state.phase == PHASE.STOPPED then
        return false, "no_running_match"
    end
    state.phase = PHASE.STOPPED
    state.stop_reason = reason or "server_stopped"
    return true
end

function MatchManager.shutdown()
    if state.phase ~= PHASE.WAITING and state.phase ~= PHASE.FINISHED
        and state.phase ~= PHASE.STOPPED then
        MatchManager.stop("plugin_shutdown")
    end
end

function MatchManager.snapshot()
    local result = {
        phase = state.phase,
        match_id = state.match_id,
        winner_id = state.winner_id,
        stop_reason = state.stop_reason,
        competitors = {},
        spectators = {}
    }

    if state.roster then
        for _, slot in ipairs(state.roster.slots) do
            result.competitors[#result.competitors + 1] = {
                slot = slot.slot,
                kind = slot.kind,
                status = slot.status,
                competitor_id = slot.competitor_id,
                display_name = slot.competitor_id
                    and state.player_names[slot.competitor_id] or nil,
                elimination_reason = slot.elimination_reason
            }
        end
        for _, spectator in ipairs(state.roster.spectators) do
            result.spectators[#result.spectators + 1] = {
                player_id = spectator.player_id,
                status = spectator.status
            }
        end
        result.active_competitors = RosterManager.count_active(state.roster)
        result.roster_locked = state.roster.locked
    else
        result.active_competitors = 0
        result.roster_locked = false
    end

    return result
end

return MatchManager
