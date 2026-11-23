# Game Design

**Status:** Proposed design for the first playable game-mode milestones  
**Date:** 2026-11-23

This document defines the player-facing flow, persistent statistics, vehicle ownership model, and fixed 20-competitor roster rules. It is a design specification, not a claim that these features are implemented.

## 1. Product direction

BeamNG Eliminator should feel like a self-contained game mode inside BeamNG.drive, not a collection of unrelated server commands. The client mod provides the front end and in-game HUD; the BeamMP server remains authoritative for matchmaking, competitor slots, match state, rewards, statistics, and results.

The design is inspired by the broad structure of open-world elimination racing modes. It uses original UI, code, data, and assets.

## 2. Player flow

### Main menu

The first screen after the player opens the mode should provide:

- **Play** — join matchmaking or enter the next available match.
- **Garage** — inspect the player's collection, choose a preferred starter vehicle from the approved starter pool, and configure supported appearance options.
- **Statistics** — career totals, personal records, and mode-specific performance.
- **Match history** — recent completed matches with placements and key events.
- **Settings** — controls, HUD, audio and accessibility options.
- **How to play** — short explanation of drops, duels, arena phases and the final race.

The main menu should be implemented as a BeamNG UI app, with the client extension acting as the bridge to the server protocol. It should not require a separate external launcher.

### Matchmaking and lobby

1. The player selects Play.
2. The server places the player in a queue or the next lobby.
3. The lobby shows the roster, map, match status and countdown.
4. Players choose a spawn region while the lobby is open.
5. The server locks the roster before the countdown.
6. The client receives the confirmed spawn and match snapshot.

A player who joins after the match has started enters spectator/queue state and is eligible for the next match. They do not displace an active competitor.

## 3. Fixed 20-slot competitor roster

A match has 20 stable competitor slots. A slot is an identity in the match, not merely an entry in a list that can be freely replaced.

### Core invariants

- Every active match has at most 20 competitor slots.
- Once the match countdown locks the roster, slot ownership is immutable except for an explicit disconnect takeover policy.
- A new player joining during an active match must never cause an AI competitor to be deleted, despawned, or replaced.
- An AI competitor leaves the active roster only after a server-confirmed elimination or match termination.
- A late joiner becomes a spectator/queued player and can join the next match.
- The server owns slot assignment and broadcasts roster changes with stable competitor IDs.
- Client UI must not infer slot membership from currently visible vehicles.

### Lobby fill

Before roster lock, the server may fill vacant slots with humans and then AI. The exact fill deadline and minimum human count are configuration values. Once locked, the roster is not rebalanced when more humans connect.

Example: a match starts with 5 humans and 15 AI. If 3 more players connect after the start, the match remains 5 humans + 15 AI; the 3 newcomers spectate or queue for the next match.

### Disconnect handling

A human disconnect does not free the slot immediately. The server marks the competitor disconnected and starts a configurable reconnection grace period. If reconnection succeeds, the same competitor identity resumes. If it expires, the match may transfer control of that same competitor slot to an AI takeover controller. This is not a new competitor and must not affect any other bot slot.

AI takeover is a separate feature and must be implemented only after reconnect identity and vehicle-control synchronization are proven. If takeover is not available, the disconnected competitor is marked as abandoned and processed by an explicit match rule; other AI competitors remain untouched.

### Elimination

Elimination is a server-authoritative state transition:

1. Validate the elimination condition.
2. Mark the competitor eliminated exactly once.
3. Record placement and elimination reason.
4. Remove or disable that competitor's active vehicle through a separately verified vehicle lifecycle path.
5. Update the remaining-competitor count and notify all clients.
6. Persist the match event.

Removing an eliminated competitor's vehicle must never be implemented as a side effect of a player joining.

## 4. Garage and match vehicle separation

The permanent garage and the temporary match vehicle are separate concepts.

### Garage

The garage stores a player's preferred vehicle selection and supported appearance preferences. It is a collection/presentation feature and does not grant an unrestricted performance advantage at match start.

### Match starter vehicle

At match start, each human chooses one vehicle from a curated, balanced starter pool. If no selection is made, the server assigns a default starter. The starter pool should initially use vehicles included with BeamNG.drive to avoid mandatory third-party dependencies.

The selected starter is a match loadout, not a permanent change to the garage.

### Car Drops

- Drops offer vehicles from configured tiers.
- The server validates pickup eligibility and claims.
- A successful pickup replaces the competitor's current match vehicle according to the match rules.
- The previous match vehicle is handled by an explicit cleanup/reward policy.
- The permanent garage collection is never modified by a drop.
- Vehicle catalogue entries should use stable internal IDs and verified BeamNG vehicle/config identifiers.

The initial ten-tier idea remains a balancing target. The actual catalogue must be built from verified in-game vehicle identifiers and tested configs, not guessed model names.

## 5. Career statistics and match history

The server is the source of truth for all ranked statistics. Clients may display cached snapshots but cannot submit authoritative totals.

### Career statistics

Recommended initial metrics:

- Matches played.
- Wins, top-3 finishes and win rate.
- Average and best placement.
- Head-to-head challenges, wins and losses.
- Competitors eliminated.
- Car Drops collected.
- Highest vehicle tier reached.
- Survival time and distance driven.
- Current and best win streak.

Metrics should be derived from validated match events where possible, rather than incremented by untrusted client requests.

### Match history

Each completed match record should contain:

- Match ID, start/end timestamps, map ID and ruleset version.
- Competitor IDs and public display names as permitted by server policy.
- Final placement and outcome for each competitor.
- Starter and final vehicle IDs/tiers.
- Duel results.
- Drop pickups.
- Elimination time and reason.
- Winner and final showdown result.

Do not store IP addresses or unrelated connection identifiers in player profiles or public match history. Use a server-generated opaque profile ID, with any account-binding mechanism kept private and documented separately.

### Persistence

Introduce a storage interface before selecting a concrete backend. The first implementation must verify the BeamMP server runtime's supported persistence options and failure behavior. Do not assume undocumented filesystem helpers or silently keep career data only in memory.

Writes should be resilient to server shutdown: match events and completed results need a clear flush/commit policy, schema versioning, and backup guidance. A storage failure must be logged and must not fabricate successful career updates.

## 6. UI surfaces

### Main menu
- Play / matchmaking.
- Garage.
- Statistics.
- Match history.
- Settings and How to play.

### Lobby
- 20-slot roster with human/AI/spectator state.
- Map and spawn-region selection.
- Ready state and countdown.
- Clear indication when the roster is locked.

### In-match HUD
- Remaining competitors (for example, 14/20).
- Current vehicle tier.
- Drop and duel prompts.
- Arena phase and boundary warning.
- Mini-map/route guidance where technically supported.
- Match status and connection/reconnect state.

### Results
- Winner and final placements.
- Eliminations and duel summary.
- Personal performance.
- Updated career statistics.
- Return to garage/menu and queue again.

## 7. Match lifecycle

Recommended state machine:

`IDLE → QUEUING → LOBBY → ROSTER_LOCKED → COUNTDOWN → ACTIVE → FINAL_SHOWDOWN → RESULTS → IDLE`

The server validates every transition. Repeated, stale or out-of-order client requests must be rejected safely.

## 8. Implementation order

1. Formalize competitor IDs, slot states and roster invariants.
2. Implement server-side match lifecycle and late-join spectator behavior.
3. Add a test harness for joins during lobby, countdown and active match.
4. Add a persistence adapter and server-derived match results.
5. Build the main menu, lobby and results UI.
6. Add garage selection and the curated starter pool.
7. Implement one synchronized AI competitor and verify it with two clients.
8. Implement drops, duels, elimination and final showdown.
9. Add full career statistics and match history views.
10. Scale AI and performance tests progressively toward 20 competitors.

## 9. Acceptance tests for the bot-retention rule

The following must pass before the mode is considered safe for public matches:

- Start with 5 humans and 15 AI; connect another human during the active match; all 15 AI competitor IDs remain present.
- Connect multiple humans during an active match; no AI slot or AI vehicle is removed because of those joins.
- Eliminate one AI; exactly that AI is marked eliminated; the other 14 remain.
- Disconnect and reconnect a human during the grace period; the same competitor ID and slot are restored.
- A late joiner is shown as spectator/queued, not inserted into the active roster.
- Duplicate elimination or join events do not create duplicate slot transitions.
- Match results and statistics agree with the server event log.

## 10. Technical constraints

BeamMP provides server-side player lifecycle events and client-side event/network APIs, but synchronized AI vehicle ownership and control still require a real multiplayer prototype. The server must not pretend it can spawn or drive AI vehicles through an undocumented API. See the dated BeamMP and client-mod research notes for the verified API boundary and remaining runtime tests.
