# The Eliminator — Gameplay and BeamMP Feasibility Research

- **Date:** 2026-11-23
- **Short description:** Research into The Eliminator's core gameplay rules and the technical feasibility of adapting its 20-competitor human/AI format to BeamNG.drive and BeamMP.
- **Status:** Initial research; exact FH5 numeric timings and multiplayer AI synchronization still require in-game and technical validation.


**Project:** BeamNG Eliminator  
**Target:** BeamNG.drive + BeamMP  
**Research date:** 2026-11-23  
**Status:** Research baseline; gameplay and network prototypes still required.

> This document studies the gameplay structure of Forza Horizon's The Eliminator and translates it into an implementation plan for BeamNG.drive. It is a research document, not a claim that these systems already exist in this repository.

## 1. Executive summary

The Eliminator is an open-world vehicle battle-royale mode. Competitors begin in low-tier vehicles, explore the map, collect vehicle drops, challenge nearby opponents to one-on-one races, and are eliminated by losing a Head-to-Head or being caught outside the shrinking arena. When the arena reaches its final stage, Head-to-Head challenges stop and the remaining competitors race to a shared destination.

The BeamNG adaptation should reproduce this gameplay loop as closely as the platform allows:

1. Fill a match with 20 active competitor slots.
2. Let players choose a spawn location on the map.
3. Start all competitors in a common low-tier vehicle.
4. Let competitors explore and collect vehicle drops.
5. Allow nearby competitors to trigger Head-to-Head races with the horn.
6. Eliminate the loser and let the winner choose a reward.
7. Contract the arena in timed stages.
8. Disable new duels at the final stage and start the Final Showdown.
9. Declare the first competitor to reach the final destination the winner.

**Important adaptation:** Forza's documented format supports up to 72 players. This project intentionally targets 20 competitors total, with human players and AI filling the same roster. Twenty is a project design decision, not a Forza rule or a proven BeamMP capacity limit.

## 2. Source-backed description of the original mode

### 2.1 Match structure

Forza Support describes The Eliminator as a Battle Royale in which up to 72 drivers compete to be the last driver standing. Competitors eliminate one another through Head-to-Head races and ultimately compete in a final race. The same support guide documents a 1–10 vehicle-level system and says the final race can include up to 12 drivers.

Sources:
- Forza Support — [FH4 Guide: How to win the Eliminator](https://support.forza.net/hc/en-us/articles/360041608973-FH4-Guide-How-to-win-the-Eliminator)
- Forza Wiki — [The Eliminator](https://forza.fandom.com/wiki/The_Eliminator) (community-maintained overview covering FH4/FH5)

The project uses the same broad structure but a 20-slot mixed human/AI roster.

### 2.2 Starting vehicle and spawn selection

The Forza Support guide describes two initial choices: a starter vehicle and a starting location. In its FH4 example, all players start in the same 1965 Mini Cooper S, then select a location on the map. The guide recommends considering both likely Car Drop locations and the expected arena contraction.

For BeamNG:
- Start with one shared starter vehicle/configuration for every competitor.
- Show a map with selectable spawn areas.
- Validate spawn points against map bounds, roads/terrain, water, obstacles, and other competitors.
- Spread initial positions so the match does not begin as one pile-up.
- Assign AI spawn points automatically using the same placement rules.

The exact BeamNG starter car and spawn point catalogue remain project configuration decisions.

Source: [Forza Support — beginning of the game](https://support.forza.net/hc/en-us/articles/360041608973-FH4-Guide-How-to-win-the-Eliminator)

### 2.3 Car Drops and vehicle levels

Forza Support describes purple flares as Car Drop indicators. A drop can provide a vehicle, and the guide notes that drops can reach level 10. It also states that players in a Head-to-Head cannot collect drops. The community-maintained overview describes the 1–10 vehicle level system and the fact that a level is a simplified performance category rather than the normal PI display.

For BeamNG:
- Maintain a configurable catalogue of vehicle model + configuration + tier.
- Spawn drops at valid, reachable map positions.
- Show a world beacon and map marker for available drops.
- Mark collected drops as unavailable for every participant.
- Prevent collection while the competitor is in a Head-to-Head or another locked state.
- Replace the competitor's current vehicle with the selected drop vehicle.
- Make AI competitors evaluate and collect drops too.
- Use the server as the authority for drop ownership and reward decisions.

**Balancing note:** Equal tier does not have to mean identical handling. BeamNG vehicles differ significantly on asphalt, dirt, rocks and jumps. Tier assignment must be tested on representative routes, not based only on top speed or horsepower.

Sources:
- [Forza Support — Collecting a Car Drop](https://support.forza.net/hc/en-us/articles/360041608973-FH4-Guide-How-to-win-the-Eliminator)
- [Forza Wiki — Car Levels and Car Drops](https://forza.fandom.com/wiki/The_Eliminator)

### 2.4 Head-to-Head challenges

The Forza Support guide says Head-to-Head is initiated with the horn when players are within range. The winner can eliminate the opponent and choose either the defeated opponent's vehicle or a vehicle one level above their current one. The community overview adds that the event is a one-on-one sprint to a selected finish point and that the loser is eliminated.

For BeamNG, the intended flow is:

1. Detect a valid nearby competitor and horn challenge.
2. Check that both competitors are eligible (alive, not already racing, not in a protected transition).
3. Create one server-side duel record with a unique ID.
4. Select a valid finish point and broadcast the duel state.
5. Show both vehicle names/tiers, a versus panel, route marker and countdown.
6. Track the race and determine the winner.
7. Eliminate the loser.
8. Give the winner a reward choice:
   - take the defeated competitor's vehicle; or
   - upgrade one tier, subject to the maximum tier.
9. Close the duel and update the roster.

The original mode's challenge behavior is not a conventional accept/decline invitation in the cited support description: the horn initiates the Head-to-Head. Therefore, the BeamNG version should default to an immediate challenge once range and eligibility checks pass. An optional server setting could add a confirmation variant, but that would be a deliberate gameplay deviation.

Finish-point selection should consider arena state, route validity, minimum/maximum distance, terrain, water, out-of-bounds regions and whether both competitors can plausibly reach the destination. Do not simply choose a random coordinate: a point may be physically unreachable or produce an unfair route.

Sources:
- [Forza Support — Head-to-Head Races](https://support.forza.net/hc/en-us/articles/360041608973-FH4-Guide-How-to-win-the-Eliminator)
- [Forza Wiki — Head-to-Head](https://forza.fandom.com/wiki/The_Eliminator)

### 2.5 Arena and contraction

The community-maintained overview describes an arena boundary shown on the map, a projected next boundary, countdown notifications, and staged contractions. The Forza Support guide explains that Head-to-Head finish points are generally placed toward the arena center and that players need to pay attention to the arena while racing.

For BeamNG:
- Define an arena as a circle or map-supported region with center and radius.
- Keep current and next-stage boundaries.
- Use a pre-shrink countdown and a visible warning.
- Contract in discrete stages rather than continuously changing the boundary without notice.
- Show the current boundary, projected boundary and direction/distance to safety.
- Apply an elimination rule to competitors who remain outside after the configured grace period.
- Make the contraction schedule configurable per map and match length.
- Prevent Head-to-Head finish points from being invalidated unfairly by a stage transition.

**Open research item:** Exact FH5 stage timings, radii and outside-arena damage/elimination behavior must be verified against current in-game footage or a reliable FH5-specific source before claiming a frame-perfect recreation. This document intentionally does not invent those numbers.

Source: [Forza Wiki — Arena](https://forza.fandom.com/wiki/The_Eliminator)

### 2.6 Final Showdown

Forza Support states that when the arena reaches its final size and the player count is 12 or fewer, new Head-to-Head races are disabled. The arena is then removed, all remaining players receive the same destination, and the first to reach it wins.

For BeamNG:
- Configure a final-stage trigger based on arena phase and remaining competitors.
- Stop starting new duels once Final Showdown begins.
- Resolve or cancel any active duel according to a documented transition rule.
- Remove/disable the arena boundary for the final race.
- Select one valid destination for all remaining competitors.
- Broadcast the same target and start state to all participants.
- Track finish arrival and award the match win to the first valid finisher.

For a 20-slot match, the original reference threshold of 12 remaining competitors is a reasonable starting point, but it must be a configurable parameter and playtested.

Source: [Forza Support — The Final Race](https://support.forza.net/hc/en-us/articles/360041608973-FH4-Guide-How-to-win-the-Eliminator)

## 3. BeamNG and BeamMP feasibility findings

### 3.1 BeamNG built-in AI

BeamNG's official AI documentation lists modes including Random, Chase, Flee, Follow, Manual, Stopping, Span and Traffic. Manual mode allows driving to a selected position; Chase/Flee/Follow require multiple vehicles. The AI Control and Traffic apps expose controls for AI vehicles.

This gives the project useful building blocks:
- Use Manual/drive-to-position behavior for drop navigation and race destinations.
- Use Random/Span/Traffic as possible roaming behaviors.
- Use Chase/Flee only where their semantics fit the intended behavior.
- Build a higher-level competitor brain that chooses goals (drop, rival, safe zone, final destination) and configures the underlying vehicle AI.

The built-in AI is not, by itself, the Eliminator bot system. It does not automatically implement vehicle-drop strategy, challenge eligibility, tier evaluation, arena decisions, elimination, or match progression.

Source: [BeamNG official documentation — AI and Traffic](https://www.docs.beamng.com/tutorials/ai/)

### 3.2 BeamMP server scripting

The current BeamMP Server Scripting Reference documents:
- Server plugins under Resources/Server.
- Client mods/resources under Resources/Client.
- Lua 5.3 for the current 3.x server plugin system.
- Custom server-to-client events, including JSON event helpers.
- Player count, player lists and player connection/disconnection events.
- Vehicle spawn and vehicle edit events.
- Position retrieval functions.

The reference specifically says onVehicleSpawn fires when a player spawns a vehicle, while vehicle swaps/replacements fire onVehicleEdited. This is relevant to enforcing match rules and validating vehicle changes, but it does not alone provide a complete NPC simulation/synchronization system.

Recommended responsibility split:
- **Server plugin:** authoritative match state, roster, drop ownership, duel state, elimination, reward selection, phase transitions and validation.
- **Client game extension:** UI, map markers, local input/horn detection, local AI control where technically appropriate, and vehicle-side operations.
- **Network protocol:** explicit, versioned events with validation, unique IDs and state snapshots.

Sources:
- [BeamMP Server Scripting Reference](https://docs.beammp.com/scripting/server/latest-server-reference/)
- [BeamMP Wiki — new Lua scripting](https://github.com/BeamMP/Wiki/blob/main/Scripting/new-lua-scripting.md)

### 3.3 The major risk: shared AI vehicle simulation

BeamNG's AI can drive vehicles locally, but a multiplayer match needs every participant to see the same NPCs in approximately the same positions and states.

A BeamMP server issue discussing server-side AI traffic describes a possible approach in which one player acts as a host, spawns and simulates AI traffic, and synchronizes positions to others; it also calls out host migration as an unpleasant problem. This is evidence that shared AI simulation is a real architectural challenge, not proof that the proposed approach is production-ready.

A community BeamMP Dynamic Traffic project demonstrates a server/client traffic module with dynamic scaling and optional traffic ghosting. Its documented example uses an AI cap of 8, so it should be treated as a reference implementation to inspect—not proof that 20 fully interactive AI competitors will work.

Recommended prototype path:
1. Spawn one AI car in a private BeamMP test.
2. Confirm all clients see it.
3. Confirm AI movement remains synchronized during turns, collisions and vehicle resets.
4. Test AI ownership when the controlling player disconnects.
5. Measure bandwidth, CPU, physics load and client frame rate.
6. Scale through 3, 5, 10 and finally 20 total competitor vehicles.

Do not assume that a client-side AI car automatically becomes a correctly synchronized shared NPC for all peers.

Sources:
- [BeamMP-Server issue #390 — Server-side AI traffic](https://github.com/BeamMP/BeamMP-Server/issues/390)
- [BeamMPDynamicTraffic repository](https://github.com/DeadEndReece/BeamMPDynamicTraffic)
- [BeamMP forum — AI traffic in multiplayer](https://forum.beammp.com/t/can-i-use-ai-traffic-while-playing-multiplayer/454561)

## 4. Proposed game architecture

### 4.1 Core managers

| Component | Responsibility |
|---|---|
| MatchManager | Match lifecycle, phases, start/end and global state |
| RosterManager | 20 competitor slots, human/AI assignment, join/leave handling |
| SpawnManager | Map spawn catalogue, player selection and AI spawn distribution |
| VehicleCatalog | Approved vehicle configs, tier definitions and compatibility |
| DropManager | Drop placement, markers, pickup locks and rewards |
| DuelManager | Horn challenges, eligibility, finish selection, race state and result |
| ArenaManager | Current/projected boundaries, countdowns and outside rules |
| EliminationManager | Competitor status and elimination reasons |
| FinalShowdownManager | Final transition, shared destination and winner |
| AICompetitorManager | AI goals, target selection, vehicle evaluation and behavior |
| HUD/UI | Lobby, map, drop markers, duel panels, arena warnings and results |

### 4.2 Match state machine

Suggested phases:

WAITING_FOR_PLAYERS → LOBBY → SPAWN_SELECTION → COUNTDOWN → ACTIVE → FINAL_PREPARATION → FINAL_SHOWDOWN → RESULTS

The server should own phase transitions. Clients receive state changes and render the appropriate UI.

### 4.3 Competitor data model

Each slot should have a stable match-local ID and fields similar to:

- competitorId
- kind (human or ai)
- playerId (human only)
- status (waiting, alive, dueling, eliminated, finished)
- vehicleModel
- vehicleConfig
- vehicleTier
- position (latest validated/synchronized state)
- spawnId
- duelId (if participating)

Do not use a player name as the unique identity. Use server-assigned IDs.

### 4.4 Drop data model

Each drop should contain:
- dropId
- vehicleModel
- vehicleConfig
- tier
- position
- rotation
- state (available, claimed, expired)
- claimedBy
- spawnTime / expiryTime

The server must validate that the drop is still available and that the claimant is eligible and close enough. The client should request a pickup; it should not decide the reward or send an arbitrary vehicle configuration as proof.

### 4.5 Duel data model

Each duel should contain:
- duelId
- competitorA
- competitorB
- finishPosition
- state (starting, running, completed, cancelled)
- startTime
- winnerId
- loserId
- rewardChoice

Only one active duel per competitor should be allowed. Finish detection needs server-side validation based on synchronized positions and a defined finish radius/volume.

## 5. Exactness: original rules vs BeamNG adaptation

| Feature | Original-mode behavior from sources | BeamNG project decision |
|---|---|---|
| Competitor count | Up to 72 in Forza | Exactly 20 active slots |
| Starter vehicle | Shared low-tier starter | Shared BeamNG starter config |
| Spawn | Choose a start location | In-game map spawn selection |
| Drops | Flare-marked car drops | World beacon + map marker |
| Vehicle tiers | 1–10 | 1–10, separately balanced for BeamNG |
| Challenge | Horn at nearby opponent | Horn-triggered server-validated duel |
| Duel finish | Selected destination | Map-valid route and finish volume |
| Duel reward | Opponent car or +1 level | Same choice, with tier cap |
| Duel loser | Eliminated | Eliminated from current match |
| Arena | Shrinking boundary | Configurable staged safe-zone contraction |
| Final | Shared destination race | Final Showdown for remaining competitors |
| AI | Forza matchmaking is player-focused | AI fills unoccupied project slots |

This table distinguishes the inspiration from deliberate changes. The 20-slot AI-filled format is not an exact copy of Forza matchmaking; it is the project's adaptation for BeamMP.

## 6. Development order and acceptance tests

The riskiest technical assumption is shared NPC simulation. Build the systems in an order that proves the multiplayer foundation before investing in a complete AI population.

### Milestone 0 — Technical spike
- [ ] Create a minimal BeamMP server plugin and client extension.
- [ ] Send a custom server-to-client event.
- [ ] Verify event payload validation and versioning.
- [ ] Spawn one test NPC vehicle.
- [ ] Verify whether all clients see synchronized movement.
- [ ] Record performance and disconnect behavior.

**Acceptance:** one NPC is visible and behaves consistently for at least two clients in a repeatable test.

### Milestone 1 — Human-only match core
- [ ] Create match state machine.
- [ ] Create 20-slot roster model.
- [ ] Add spawn selection and countdown.
- [ ] Add competitor HUD.
- [ ] Test with two or more human players.

**Acceptance:** players spawn at selected valid locations and see the same match phase and roster.

### Milestone 2 — Drops and vehicle replacement
- [ ] Add vehicle catalogue and tiers.
- [ ] Spawn one test drop.
- [ ] Add map/world marker.
- [ ] Add server-authoritative pickup claim.
- [ ] Replace vehicle and verify replication for all clients.

**Acceptance:** a drop can be claimed once only, and all clients observe the same resulting vehicle.

### Milestone 3 — Head-to-Head
- [ ] Detect horn input on the client.
- [ ] Validate challenge range and eligibility on the server.
- [ ] Select and broadcast a valid finish point.
- [ ] Track finish and determine winner.
- [ ] Eliminate loser and apply winner reward.

**Acceptance:** two human players complete a duel with one consistent winner and one elimination on every client.

### Milestone 4 — Arena and Final Showdown
- [ ] Add staged arena countdown and boundaries.
- [ ] Add outside-zone rule.
- [ ] Add final-stage transition.
- [ ] Disable new duels at final stage.
- [ ] Race all remaining competitors to one destination.

**Acceptance:** a full human-only match can reach and complete the final race.

### Milestone 5 — AI scaling
- [ ] Add one AI competitor.
- [ ] Add AI roaming and destination navigation.
- [ ] Add AI drop selection.
- [ ] Add AI duel behavior.
- [ ] Add roster fill logic.
- [ ] Scale through 3, 5, 10 and 20 competitors.

**Acceptance:** all clients see a consistent roster and NPC state at the tested scale; performance targets are documented rather than assumed.

## 7. Open questions requiring in-game verification

These details should be measured or confirmed before claiming a one-to-one FH5 recreation:

- Exact FH5 arena stage count, timing, radii and contraction schedule.
- Exact FH5 drop spawn distribution, rarity and respawn rules.
- Exact FH5 vehicle roster and per-tier assignments.
- Exact FH5 challenge range and any cooldown/eligibility edge cases.
- Exact outside-arena elimination timing and UI behavior.
- Final Showdown trigger details for the FH5 implementation.
- BeamMP NPC synchronization limits under the target server version and map.
- Whether a stable AI controller handoff can be implemented when a host disconnects.

The official Forza Support article cited below is an FH4 guide. It is useful for documented core rules, but it must not be presented as definitive proof of every FH5-specific numeric value. The community wiki covers FH5 as well, but should be cross-checked against current gameplay footage for exact timing and balance values.

## 8. Sources

1. **Forza Support — FH4 Guide: How to win the Eliminator**  
   https://support.forza.net/hc/en-us/articles/360041608973-FH4-Guide-How-to-win-the-Eliminator  
   Official support article covering the mode loop, starter car, spawn choice, drops, Head-to-Head rewards and Final Race.

2. **Forza Wiki — The Eliminator**  
   https://forza.fandom.com/wiki/The_Eliminator  
   Community-maintained overview covering FH4/FH5, Head-to-Head, arena, stages and car levels. Use with cross-checking for exact FH5 details.

3. **BeamNG Documentation — AI and Traffic**  
   https://www.docs.beamng.com/tutorials/ai/  
   Official description of built-in AI modes and traffic controls.

4. **BeamMP Documentation — Server Scripting Reference (3.x)**  
   https://docs.beammp.com/scripting/server/latest-server-reference/  
   Official server Lua plugin structure, events, custom client events and vehicle/player APIs.

5. **BeamMP Wiki — New Lua scripting**  
   https://github.com/BeamMP/Wiki/blob/main/Scripting/new-lua-scripting.md  
   BeamMP scripting reference material.

6. **BeamMP-Server issue #390 — Server-side AI traffic**  
   https://github.com/BeamMP/BeamMP-Server/issues/390  
   Discussion of the difficulty of shared AI traffic and a possible client-hosted simulation approach.

7. **BeamMPDynamicTraffic**  
   https://github.com/DeadEndReece/BeamMPDynamicTraffic  
   Community server/client dynamic traffic project; useful as a code reference, not a drop-in Eliminator AI solution.

8. **BeamMP Forum — Can I use AI Traffic while playing Multiplayer?**  
   https://forum.beammp.com/t/can-i-use-ai-traffic-while-playing-multiplayer/454561  
   Community discussion of vehicle caps and multiplayer traffic constraints.

---

## Conclusion

The core Eliminator loop is implementable as a BeamNG game mode in principle, but the project is not just a collection of UI scripts. The critical engineering challenge is synchronizing AI-controlled physical vehicles across BeamMP clients while keeping match outcomes authoritative.

The recommended first proof is **one shared AI vehicle in a two-client BeamMP session**. Once that works reliably, the project can build the match, drops, duels, arena and final race around it, then scale toward the 20-competitor target.
