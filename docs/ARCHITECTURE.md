# Architecture

## Components

| Component | Runtime | Authority |
|---|---|---|
| `server-plugin/` | BeamMP Server Lua | Match state, roster, validation and results |
| `client-mod/` | BeamNG.drive Lua/UI | Input, presentation, vehicle and AI prototypes |
| `client-mod/ui/modules/apps/EliminatorLobby/` | BeamNG AngularJS UI app | Read-only 20-slot lobby presentation |
| `shared/` | Source/configuration | Versioned protocol and common rules |
| `tests/` | Python 3, Lua 5.1/5.3 and Node.js | Offline structural/configuration checks, lobby UI contract/state checks, client-extension bridge tests, pure-Lua logic tests and mocked BeamMP adapter tests |

## Loading and packaging

- BeamMP server plugin: `Resources/Server/Eliminator/main.lua` plus its `modules/` directory.
- BeamMP client resource: one ZIP in `Resources/Client/`.
- Client ZIP entry script: `scripts/modScript.lua`, which loads the GE extension `eliminator`.
- GE extension entry point: `lua/ge/extensions/eliminator.lua`.
- Native lobby app: `ui/modules/apps/EliminatorLobby/` (`app.json`, `app.js`, `app.html`, `app.css`, `app.png`).

The server plugin uses BeamMP `onInit`/`onShutdown` lifecycle hooks and registers `onPlayerJoin`, `onPlayerDisconnect`, `onConsoleInput` and `onChatMessage`. Its internal Lua modules remain in a subdirectory and are loaded explicitly.

## Authority model

The server owns the official match state. Clients send requests; the server validates them and broadcasts accepted state changes. Client-side physics and AI vehicle control are separate engineering problems and must be verified in multiplayer before being treated as synchronized gameplay.

## AI synchronization gate

The first AI milestone is not "20 bots". It is one AI-controlled vehicle observed consistently by two clients. The prototype must establish:

1. Which client or runtime owns the vehicle simulation.
2. How vehicle state is replicated to other clients.
3. What happens when the controlling client disconnects.
4. How server-side match identity maps to the client-side vehicle.
5. Whether control remains stable under latency and packet loss.

Only after this gate passes should the project scale to 3, 5, 10 and 20 competitors.

## Build outputs

- Server plugin: `dist/Resources/Server/Eliminator/`
- Client mod: `dist/Eliminator-client.zip`

Builds are local. This repository does not add scheduled GitHub Actions workflows.

## Roster logic prototype and tests

`server-plugin/modules/roster_manager.lua` now contains a pure-Lua roster model:
- Human players claim vacant slots while the lobby is open.
- Locking the roster fills all remaining slots with deterministic AI competitor IDs.
- Late joiners are recorded as spectators and cannot mutate locked competitor slots.
- Elimination marks only the addressed competitor; the slot identity remains available for results/history.

The module deliberately does not spawn or delete BeamNG vehicles. Vehicle lifecycle operations require a separately verified BeamMP/BeamNG synchronization implementation.

Run its logic tests from the repository root with:

```sh
lua5.3 tests/lua/test_roster_manager.lua
```

The CI workflow runs this test after installing Lua 5.3. Python tests check repository structure, JSON validity, protocol/configuration consistency and lobby UI assets. Node.js checks the UI directive syntax and exercises lobby state updates; a Lua 5.1 mocked test checks the client extension's event bridge. These are offline checks, not a real BeamMP server integration test.

## Match lifecycle manager

`server-plugin/modules/match_manager.lua` now coordinates the server-side lifecycle and composes the roster model.

Implemented transitions and operations:
- `waiting → lobby`: create a match with a unique match ID.
- Lobby joins claim human slots; the lobby rejects joins after its capacity is reached.
- `lobby → starting`: lock the roster, enforce the configured minimum human count, and optionally fill vacant slots with AI identities.
- `starting → active`: begin the match after the external countdown/ready gate.
- `active → final_showdown`: enter the final race phase when the game rules decide it is time.
- `active/final_showdown`: process a single validated elimination without changing unrelated slots.
- `final_showdown → finished`: accept a winner only if that competitor is still active.
- Running phases can be stopped with a recorded reason; a new lobby can then be created.

Numeric BeamMP runtime player IDs are normalized into match-scoped string competitor IDs; these IDs are not durable account/profile identifiers. The module returns snapshots rather than exposing its internal roster tables. Late joins in starting, active or final-showdown phases are spectators. The server entry point now connects the manager to player join/disconnect events, server-console commands and a one-second event timer used for a ten-second countdown. The adapter broadcasts versioned match snapshots and countdown messages; the client extension receives and validates those envelopes. This is an API-backed integration prototype, not yet a live-server compatibility test. Match results are not persisted.

Pure-Lua lifecycle tests live in `tests/lua/test_match_manager.lua`; mocked adapter tests live in `tests/lua/test_server_adapter.lua`. Both are included in CI and local build checks when Lua 5.3 is available.

## Stable competitor slots

The match roster is a server-owned set of 20 stable competitor identities. Slot assignment is locked before the countdown. A late player join is a spectator/queue event, never a reason to remove or despawn an AI competitor. AI removal is allowed only after a validated elimination or match termination.

A disconnected human retains the same active competitor slot and is marked `connection_status = disconnected`; the match is not silently changed into an elimination. Reconnection with the same BeamMP runtime player ID restores that slot. There is not yet a timed reconnect grace period, cross-ID account matching, or AI takeover. If AI takeover is later implemented, it must take over that same identity and slot without affecting other bots.

## Player data and statistics

The server derives match results and career statistics from validated events. The client is a presentation layer and cannot authoritatively increment wins, eliminations or drop counts. Persistent profiles use opaque server-side identifiers; connection IPs and unrelated connection metadata must not be copied into player profiles or public match history.

A storage adapter must be selected only after verifying the target BeamMP runtime's supported persistence mechanisms. Do not rely on undocumented filesystem APIs. The data model and player-facing screens are specified in [GAME_DESIGN.md](GAME_DESIGN.md).

## Main menu and vehicle ownership

The in-game UI provides Play, Garage, Statistics, Match History, Settings and How to Play. The permanent garage selection is separate from the temporary match vehicle. Players choose a balanced starter vehicle; Car Drops change only the current match vehicle and never overwrite the permanent garage collection.

## BeamMP event adapter

The root server entry point registers the documented BeamMP events and exposes these server-console commands:

- `eliminator status` — print phase, active count, spectators and match ID.
- `eliminator lobby` — create a new lobby when no match is running.
- `eliminator start` — validate and lock the roster, then start a 10-second countdown.
- `eliminator stop` — stop the current match and cancel the countdown.
- `!eliminator` — player chat status command.

Player joins during an open lobby claim slots. Joins after roster lock become spectators. Disconnects mark human competitors as disconnected without eliminating them. A disconnected lobby competitor prevents the match from starting; a disconnect during countdown cancels the countdown, clears only generated AI placeholders and reopens the lobby. Reconnection with the same runtime ID restores the original slot.

The server sends `match.snapshot` and `match.countdown` envelopes through BeamMP client events. The client validates protocol version/type before retaining the received state. A native AngularJS lobby app receives the cached snapshot and countdown through the namespaced `EliminatorLobbyUpdate` guihooks event and displays all 20 logical slots, player/AI/empty state, disconnected/eliminated state, spectators, match phase and countdown.

The lobby app is currently read-only. It has no Ready/Leave controls, spawn selection or client-to-server actions because those request handlers and server validations are not implemented yet. AI roster entries remain logical identities, not spawned or synchronized vehicles. The UI app and event bridge have not yet been verified in a live BeamNG/BeamMP session.

The adapter uses `MP.TriggerClientEventJson` when available (BeamMP Server 3.1.0+) and falls back to `MP.TriggerClientEvent` with `Util.JsonEncode`. The timer interval is 1000 ms. Mocked API tests check registration, commands, countdown, snapshots, disconnect handling and countdown rollback. Only a live target-server smoke test can confirm runtime compatibility and actual delivery to BeamNG clients.
