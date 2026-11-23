-- Pure-Lua tests for the server-side match lifecycle.
package.path = "./server-plugin/?.lua;./server-plugin/?/init.lua;" .. package.path

local MatchManager = require("modules.match_manager")

local function expect(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

local function ready_all_humans()
    for _, c in ipairs(MatchManager.snapshot().competitors) do
        if c.kind == "human" and c.status == "active" then
            expect(MatchManager.select_spawn_region(c.competitor_id, "north"))
            expect(MatchManager.set_player_ready(c.competitor_id, true))
        end
    end
end
local function test_full_lifecycle_and_late_join()
    local ok, reason = MatchManager.initialize({
        competitor_limit = 20,
        minimum_human_players = 1,
        fill_open_slots_with_ai = true
    })
    expect(ok, "manager initialization failed: " .. tostring(reason))

    local created, snapshot = MatchManager.create_lobby("match:test:001")
    expect(created and snapshot.phase == "lobby", "lobby should be created")
    expect(snapshot.active_competitors == 0, "new lobby should be empty")

    for index = 1, 5 do
        local joined, result = MatchManager.add_player(
            "player:" .. index,
            "Driver " .. index
        )
        expect(joined and result.role == "competitor", "human should join lobby")
        expect(result.slot == index, "human should receive expected slot")
    end

    ready_all_humans()
    local locked, lock_result = MatchManager.lock_roster()
    expect(locked, "roster lock failed: " .. tostring(lock_result))
    expect(lock_result.ai_added == 15, "five humans should create fifteen AI competitors")
    expect(lock_result.snapshot.phase == "starting", "lock should enter starting phase")
    expect(lock_result.snapshot.roster_locked, "roster should be locked")
    expect(lock_result.snapshot.active_competitors == 20, "all twenty slots should be active")

    local late_starting, late_result = MatchManager.add_player("late:starting", "Late Starting")
    expect(late_starting and late_result.role == "spectator",
        "join during countdown must be spectator")

    local started, start_reason = MatchManager.start_match()
    expect(started, "match should start: " .. tostring(start_reason))
    expect(MatchManager.snapshot().phase == "active", "phase should be active")

    local ai_ids_before = {}
    for index = 6, 20 do
        ai_ids_before[index] = MatchManager.snapshot().competitors[index].competitor_id
    end

    for index = 1, 4 do
        local joined, result = MatchManager.add_player(
            "late:active:" .. index,
            "Spectator " .. index
        )
        expect(joined and result.role == "spectator",
            "join during active match must be spectator")
    end

    local after_joins = MatchManager.snapshot()
    expect(after_joins.active_competitors == 20,
        "late joins must not alter active competitor count")
    expect(#after_joins.spectators == 5,
        "countdown and active late joiners should be spectators")

    for index = 6, 20 do
        local competitor = after_joins.competitors[index]
        expect(competitor.kind == "ai", "late join removed an AI competitor")
        expect(competitor.competitor_id == ai_ids_before[index],
            "late join changed an AI identity")
        expect(competitor.status == "active", "late join deactivated an AI")
    end

    local eliminated, elimination = MatchManager.eliminate("ai:6", "duel_lost")
    expect(eliminated and elimination.slot == 6, "one AI should be eliminated")
    expect(elimination.active_competitors == 19, "one elimination should leave 19 active")

    local showdown, showdown_reason = MatchManager.begin_final_showdown()
    expect(showdown, "final showdown should start: " .. tostring(showdown_reason))
    expect(MatchManager.snapshot().phase == "final_showdown",
        "phase should be final_showdown")

    local finished, finish_result = MatchManager.finish("player:1")
    expect(finished, "active competitor should be accepted as winner")
    expect(finish_result.phase == "finished", "match should finish")
    expect(finish_result.winner_id == "player:1", "winner should be recorded")

    local after_finish, finish_reason = MatchManager.add_player("late:finished")
    expect(not after_finish and finish_reason == "match_not_accepting_players",
        "finished match should reject new participants")
end

local function test_transition_guards_and_invalid_config()
    local ok, reason = MatchManager.initialize({ competitor_limit = 21 })
    expect(not ok and reason == "invalid_competitor_limit",
        "capacity above project limit should be rejected")

    local initialized = MatchManager.initialize({
        competitor_limit = 4,
        minimum_human_players = 2,
        fill_open_slots_with_ai = true
    })
    expect(initialized, "valid small test configuration should initialize")

    local created = MatchManager.create_lobby("match:test:002")
    expect(created, "second lobby should be created")

    local no_humans, no_humans_reason = MatchManager.lock_roster()
    expect(not no_humans and no_humans_reason == "minimum_humans_not_met",
        "minimum human count must be enforced")
    expect(MatchManager.snapshot().phase == "lobby",
        "failed roster lock must leave lobby open")

    local joined = MatchManager.add_player("player:a", "A")
    expect(joined, "first human should join")
    local ready_without_region, ready_reason = MatchManager.set_player_ready("player:a", true)
    expect(not ready_without_region and ready_reason == "spawn_region_required")
    ready_all_humans()
    local still_short, still_short_reason = MatchManager.lock_roster()
    expect(not still_short and still_short_reason == "minimum_humans_not_met",
        "one human must not satisfy a two-human minimum")

    local second_joined = MatchManager.add_player("player:b", "B")
    expect(second_joined, "second human should join")
    ready_all_humans()
    local locked = MatchManager.lock_roster()
    expect(locked, "lobby should lock after minimum humans join")

    local duplicate_start = MatchManager.start_match()
    expect(duplicate_start, "first start should succeed")
    local second_start, second_start_reason = MatchManager.start_match()
    expect(not second_start and second_start_reason == "invalid_phase:active",
        "repeated start must be rejected")

    local invalid_winner, winner_reason = MatchManager.finish("not-a-competitor")
    expect(not invalid_winner and winner_reason == "final_showdown_not_active",
        "finish must not bypass final showdown")
end

local function test_numeric_beammp_player_ids()
    MatchManager.initialize({
        competitor_limit = 2,
        minimum_human_players = 1,
        fill_open_slots_with_ai = true
    })
    MatchManager.create_lobby("match:test:numeric")

    local joined, result = MatchManager.add_player(42, "Numeric Player")
    expect(joined and result.role == "competitor",
        "numeric BeamMP player ID should be accepted")
    expect(result.competitor_id == "player:42",
        "numeric player ID should be normalized to a match-scoped ID")

    ready_all_humans()
    local locked, lock_result = MatchManager.lock_roster()
    expect(locked and lock_result.ai_added == 1,
        "numeric human player should count toward minimum and AI fill")
    MatchManager.start_match()

    local late, late_result = MatchManager.add_player(99, "Late Numeric Player")
    expect(late and late_result.role == "spectator",
        "numeric late joiner should become spectator")
    expect(late_result.competitor_id == "player:99",
        "late numeric ID should be normalized")
    local snapshot = MatchManager.snapshot()
    expect(snapshot.active_competitors == 2,
        "numeric late join must not replace the active AI")
    expect(snapshot.competitors[2].competitor_id == "ai:2",
        "AI identity must remain unchanged after numeric late join")
end

local function test_disconnect_and_same_id_reconnect()
    MatchManager.initialize({
        competitor_limit = 3,
        minimum_human_players = 1,
        fill_open_slots_with_ai = true
    })
    MatchManager.create_lobby("match:test:disconnect")

    local joined, result = MatchManager.add_player(77, "Reconnect Tester")
    expect(joined and result.slot == 1, "human should join before disconnect")

    local disconnected, disconnect_result = MatchManager.disconnect_player(77)
    expect(disconnected and disconnect_result.role == "competitor",
        "disconnect should retain the human competitor slot")
    expect(MatchManager.snapshot().competitors[1].connection_status == "disconnected",
        "disconnect status should be visible in snapshot")

    local lock, lock_reason = MatchManager.lock_roster()
    expect(not lock and lock_reason == "human_disconnected",
        "lobby must not start while a human competitor is disconnected")

    local rejoined, reconnect_result = MatchManager.add_player(77, "Reconnect Tester")
    expect(rejoined and reconnect_result.reconnected,
        "same runtime ID should reclaim its existing slot")
    expect(reconnect_result.slot == 1, "reconnect must preserve the original slot")
    expect(MatchManager.snapshot().competitors[1].connection_status == "connected",
        "reconnect should restore connected status")

    ready_all_humans()
    local locked = MatchManager.lock_roster()
    expect(locked, "lobby should lock after player reconnects")
end

local function test_abort_countdown_reopens_lobby()
    MatchManager.initialize({
        competitor_limit = 4,
        minimum_human_players = 1,
        fill_open_slots_with_ai = true
    })
    MatchManager.create_lobby("match:test:abort")
    MatchManager.add_player(88, "Countdown Driver")

    ready_all_humans()
    local locked, lock_result = MatchManager.lock_roster()
    expect(locked and lock_result.ai_added == 3,
        "countdown test should fill three AI slots")
    local disconnected = MatchManager.disconnect_player(88)
    expect(disconnected, "human should disconnect during countdown")

    local aborted, snapshot =
        MatchManager.abort_starting("human_disconnected_during_countdown")
    expect(aborted, "starting phase should be abortable")
    expect(snapshot.phase == "lobby", "aborted countdown should reopen lobby")
    expect(not snapshot.roster_locked, "aborted countdown should unlock roster")
    expect(snapshot.competitors[1].competitor_id == "player:88",
        "human identity should remain in the original slot")
    expect(snapshot.competitors[1].connection_status == "disconnected",
        "human connection state should remain disconnected")
    expect(snapshot.competitors[2].status == "vacant"
        and snapshot.competitors[2].kind == "empty",
        "generated AI placeholder should be cleared on pre-match abort")
    expect(snapshot.active_competitors == 1,
        "only the original human slot should remain active")
end

local function test_stop_and_restart()
    MatchManager.initialize()
    MatchManager.create_lobby("match:test:003")
    MatchManager.add_player("player:stop", "Stop Tester")

    local stopped = MatchManager.stop("test_shutdown")
    expect(stopped, "running lobby should be stoppable")
    local stopped_snapshot = MatchManager.snapshot()
    expect(stopped_snapshot.phase == "stopped", "stopped phase should be recorded")
    expect(stopped_snapshot.stop_reason == "test_shutdown", "stop reason should be retained")

    local restarted = MatchManager.create_lobby("match:test:004")
    expect(restarted, "new lobby should be allowed after stop")
    expect(MatchManager.snapshot().match_id == "match:test:004",
        "new match should replace old match state")
end

test_full_lifecycle_and_late_join()
test_transition_guards_and_invalid_config()
test_numeric_beammp_player_ids()
test_disconnect_and_same_id_reconnect()
test_abort_countdown_reopens_lobby()
test_stop_and_restart()

print("PASS: match lifecycle (lobby, lock, countdown, active, showdown, results, late joins)")
