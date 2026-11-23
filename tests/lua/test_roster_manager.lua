-- Executable pure-Lua tests for the stable 20-slot competitor roster.
package.path = "./server-plugin/?.lua;./server-plugin/?/init.lua;" .. package.path

local RosterManager = require("modules.roster_manager")

local function expect(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

local function test_five_humans_fifteen_ai()
    local roster = RosterManager.create_empty_roster(20)

    for index = 1, 5 do
        local ok, slot = RosterManager.add_human(roster, "player:" .. index)
        expect(ok, "human should claim a lobby slot")
        expect(slot == index, "humans should claim the first available slots")
    end

    local ok, ai_count = RosterManager.lock_and_fill_ai(roster)
    expect(ok, "lobby should lock")
    expect(ai_count == 15, "five humans should leave fifteen AI slots")
    expect(roster.locked, "roster must be locked")
    expect(RosterManager.count_active(roster) == 20, "roster must contain 20 active competitors")

    for index = 1, 5 do
        expect(roster.slots[index].kind == "human", "human slot kind changed")
        expect(roster.slots[index].competitor_id == "player:" .. index, "human identity changed")
    end
    for index = 6, 20 do
        expect(roster.slots[index].kind == "ai", "remaining slots must be AI")
        expect(roster.slots[index].competitor_id == "ai:" .. index, "AI identity must be deterministic")
    end

    return roster
end

local function test_late_joins_never_replace_ai(roster)
    local ai_ids_before = {}
    for index = 6, 20 do
        ai_ids_before[index] = roster.slots[index].competitor_id
    end

    for index = 1, 3 do
        local ok, status = RosterManager.add_late_joiner(roster, "late-player:" .. index)
        expect(ok and status == "spectating", "late joiner should become spectator")
    end

    expect(#roster.spectators == 3, "all late joiners should be recorded as spectators")
    expect(RosterManager.count_active(roster) == 20, "late joins must not change active roster size")

    for index = 6, 20 do
        expect(roster.slots[index].kind == "ai", "late join removed an AI slot")
        expect(roster.slots[index].competitor_id == ai_ids_before[index], "late join changed an AI identity")
        expect(roster.slots[index].status == "active", "late join deactivated an AI")
    end

    local ok, status = RosterManager.add_late_joiner(roster, "late-player:1")
    expect(ok and status == "already_spectating", "duplicate late join should be idempotent")
    expect(#roster.spectators == 3, "duplicate late join must not duplicate spectator entry")

    local added, reason = RosterManager.add_human(roster, "late-player:4")
    expect(not added and reason == "roster_locked", "normal slot claim must fail after lock")
end

local function test_elimination_changes_only_target(roster)
    local target_id = roster.slots[6].competitor_id
    local ok, slot = RosterManager.eliminate(roster, target_id, "duel_lost")
    expect(ok and slot == 6, "target AI should be eliminated")
    expect(roster.slots[6].status == "eliminated", "target AI status should change")
    expect(roster.slots[6].elimination_reason == "duel_lost", "elimination reason should be stored")
    expect(RosterManager.count_active(roster) == 19, "exactly one competitor should be eliminated")

    for index = 7, 20 do
        expect(roster.slots[index].status == "active", "unrelated AI competitor was affected")
    end

    local repeated, reason = RosterManager.eliminate(roster, target_id, "duplicate_event")
    expect(not repeated and reason == "already_eliminated", "duplicate elimination must be rejected")
    expect(RosterManager.count_active(roster) == 19, "duplicate elimination must not change counts")
end

local function test_lobby_full_and_validation()
    local roster = RosterManager.create_empty_roster(20)
    for index = 1, 20 do
        local ok = RosterManager.add_human(roster, "full-player:" .. index)
        expect(ok, "each available lobby slot should be claimable")
    end

    local ok, reason = RosterManager.add_human(roster, "extra-player")
    expect(not ok and reason == "roster_full", "21st lobby player must be rejected")

    local locked, ai_count = RosterManager.lock_and_fill_ai(roster)
    expect(locked and ai_count == 0, "full human lobby should not create AI slots")

    local relock, relock_reason = RosterManager.lock_and_fill_ai(roster)
    expect(not relock and relock_reason == "already_locked", "roster must not lock twice")

    local invalid = RosterManager.add_late_joiner(roster, "")
    expect(not invalid, "empty player IDs must be rejected")
end

local roster = test_five_humans_fifteen_ai()
test_late_joins_never_replace_ai(roster)
test_elimination_changes_only_target(roster)
test_lobby_full_and_validation()

print("PASS: roster invariants (20 slots, late joins, AI retention, elimination, duplicates)")
