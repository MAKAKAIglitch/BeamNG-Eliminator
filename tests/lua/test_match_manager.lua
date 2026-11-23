-- Pure-Lua tests for the server-side match lifecycle.
package.path = "./server-plugin/?.lua;./server-plugin/?/init.lua;" .. package.path

local MatchManager = require("modules.match_manager")

local function expect(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
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
    local still_short, still_short_reason = MatchManager.lock_roster()
    expect(not still_short and still_short_reason == "minimum_humans_not_met",
        "one human must not satisfy a two-human minimum")

    local second_joined = MatchManager.add_player("player:b", "B")
    expect(second_joined, "second human should join")
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
test_stop_and_restart()

print("PASS: match lifecycle (lobby, lock, countdown, active, showdown, results, late joins)")
