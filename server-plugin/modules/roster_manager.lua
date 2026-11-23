-- Pure-Lua competitor roster model.
-- This module manages identities and match slots only. It does not spawn,
-- despawn, or control BeamNG vehicles.

local RosterManager = {}

RosterManager.CAPACITY = 20

local function valid_id(value)
    return type(value) == "string" and value ~= ""
end

local function find_competitor(roster, competitor_id)
    for _, slot in ipairs(roster.slots) do
        if slot.competitor_id == competitor_id then
            return slot
        end
    end
    return nil
end

local function find_spectator(roster, player_id)
    for _, spectator in ipairs(roster.spectators) do
        if spectator.player_id == player_id then
            return spectator
        end
    end
    return nil
end

function RosterManager.create_empty_roster(capacity)
    capacity = capacity or RosterManager.CAPACITY
    assert(type(capacity) == "number" and capacity >= 1 and capacity % 1 == 0,
        "capacity must be a positive integer")

    local roster = {
        capacity = capacity,
        locked = false,
        slots = {},
        spectators = {}
    }

    for slot = 1, capacity do
        roster.slots[slot] = {
            slot = slot,
            kind = "empty",
            status = "vacant",
            competitor_id = nil
        }
    end

    return roster
end

-- Human players may claim vacant slots only while the lobby is open.
function RosterManager.add_human(roster, player_id)
    if not valid_id(player_id) then
        return false, "invalid_player_id"
    end
    if roster.locked then
        return false, "roster_locked"
    end
    if find_competitor(roster, player_id) or find_spectator(roster, player_id) then
        return false, "duplicate_player"
    end

    for _, slot in ipairs(roster.slots) do
        if slot.status == "vacant" then
            slot.kind = "human"
            slot.status = "active"
            slot.competitor_id = player_id
            return true, slot.slot
        end
    end

    return false, "roster_full"
end

-- Lock the lobby and fill every remaining slot with a deterministic AI ID.
-- No AI entity is spawned here; this is only the authoritative roster model.
function RosterManager.lock_and_fill_ai(roster, ai_id_prefix, minimum_humans)
    if roster.locked then
        return false, "already_locked"
    end

    minimum_humans = minimum_humans or 1
    if type(minimum_humans) ~= "number"
        or minimum_humans < 1
        or minimum_humans % 1 ~= 0
        or minimum_humans > roster.capacity then
        return false, "invalid_minimum_humans"
    end

    local human_count = 0
    for _, slot in ipairs(roster.slots) do
        if slot.kind == "human" and slot.status == "active" then
            human_count = human_count + 1
        end
    end
    if human_count < minimum_humans then
        return false, "minimum_humans_not_met"
    end

    ai_id_prefix = ai_id_prefix or "ai:"
    if not valid_id(ai_id_prefix) then
        return false, "invalid_ai_id_prefix"
    end

    local assignments = {}
    for _, slot in ipairs(roster.slots) do
        if slot.status == "vacant" then
            local competitor_id = ai_id_prefix .. tostring(slot.slot)
            if find_competitor(roster, competitor_id) then
                return false, "duplicate_ai_id"
            end
            assignments[#assignments + 1] = {
                slot = slot,
                competitor_id = competitor_id
            }
        end
    end

    for _, assignment in ipairs(assignments) do
        assignment.slot.kind = "ai"
        assignment.slot.status = "active"
        assignment.slot.competitor_id = assignment.competitor_id
    end

    roster.locked = true
    return true, #assignments
end

-- Players arriving after roster lock are recorded as spectators.
-- This function deliberately never mutates competitor slots.
function RosterManager.add_late_joiner(roster, player_id)
    if not valid_id(player_id) then
        return false, "invalid_player_id"
    end
    if not roster.locked then
        return false, "roster_not_locked"
    end
    if find_competitor(roster, player_id) then
        return false, "already_competitor"
    end
    if find_spectator(roster, player_id) then
        return true, "already_spectating"
    end

    roster.spectators[#roster.spectators + 1] = {
        player_id = player_id,
        status = "spectating"
    }
    return true, "spectating"
end

-- Mark one competitor eliminated. The slot and identity are retained so
-- results/history can refer to them. Vehicle cleanup is a separate system.
function RosterManager.eliminate(roster, competitor_id, reason)
    if not valid_id(competitor_id) then
        return false, "invalid_competitor_id"
    end

    local competitor = find_competitor(roster, competitor_id)
    if not competitor then
        return false, "competitor_not_found"
    end
    if competitor.status == "eliminated" then
        return false, "already_eliminated"
    end
    if competitor.status ~= "active" then
        return false, "competitor_not_active"
    end

    competitor.status = "eliminated"
    competitor.elimination_reason = reason or "unspecified"
    return true, competitor.slot
end

function RosterManager.count_active(roster)
    local count = 0
    for _, slot in ipairs(roster.slots) do
        if slot.status == "active" then
            count = count + 1
        end
    end
    return count
end

return RosterManager
