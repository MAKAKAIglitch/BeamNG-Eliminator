# Architecture

## Components

| Component | Runtime | Authority |
|---|---|---|
| `server-plugin/` | BeamMP Server Lua | Match state, roster, validation and results |
| `client-mod/` | BeamNG.drive Lua/UI | Input, presentation, vehicle and AI prototypes |
| `shared/` | Source/configuration | Versioned protocol and common rules |
| `tests/` | Python 3 and Lua 5.3 | Offline structural/configuration checks and pure-Lua roster logic tests |

## Loading and packaging

- BeamMP server plugin: `Resources/Server/Eliminator/main.lua` plus its `modules/` directory.
- BeamMP client resource: one ZIP in `Resources/Client/`.
- Client ZIP entry script: `scripts/modScript.lua`, which loads the GE extension `eliminator`.
- GE extension entry point: `lua/ge/extensions/eliminator.lua`.

The server plugin uses the BeamMP `onInit` and `onShutdown` lifecycle hooks. Its internal Lua modules remain in a subdirectory and are loaded explicitly.

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

The CI workflow runs this test after installing Lua 5.3. Python tests check repository structure, JSON validity and protocol/configuration consistency. These are offline logic checks, not a real BeamMP server integration test.

## Stable competitor slots

The match roster is a server-owned set of 20 stable competitor identities. Slot assignment is locked before the countdown. A late player join is a spectator/queue event, never a reason to remove or despawn an AI competitor. AI removal is allowed only after a validated elimination or match termination.

A disconnected human retains the same competitor identity during a reconnect grace period. If AI takeover is later implemented, it takes over that same identity and slot; it does not affect any other bot. This behavior depends on verified vehicle-control handoff and is not part of the initial scaffold.

## Player data and statistics

The server derives match results and career statistics from validated events. The client is a presentation layer and cannot authoritatively increment wins, eliminations or drop counts. Persistent profiles use opaque server-side identifiers; connection IPs and unrelated connection metadata must not be copied into player profiles or public match history.

A storage adapter must be selected only after verifying the target BeamMP runtime's supported persistence mechanisms. Do not rely on undocumented filesystem APIs. The data model and player-facing screens are specified in [GAME_DESIGN.md](GAME_DESIGN.md).

## Main menu and vehicle ownership

The in-game UI provides Play, Garage, Statistics, Match History, Settings and How to Play. The permanent garage selection is separate from the temporary match vehicle. Players choose a balanced starter vehicle; Car Drops change only the current match vehicle and never overwrite the permanent garage collection.
