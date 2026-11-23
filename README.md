# BeamNG Eliminator

**A 20-competitor automotive battle royale for BeamNG.drive, powered by BeamMP.**

BeamNG Eliminator is a planned multiplayer game mode inspired by the open-world elimination-racing format popularized by *The Eliminator* in Forza Horizon. It brings the idea to BeamNG.drive: explore a large map, find better vehicles, challenge rivals, survive the match, and win the final race.

The project is intended to support **exactly 20 active competitors per match**, combining human players with AI-controlled opponents.

> **Project status:** Architecture foundation (v0.1.0). The repository now contains an initial server/client scaffold and offline checks, but it is not a playable game mode. Gameplay features listed below remain planned unless explicitly marked otherwise.

## Core concept

- 20 active competitors in every match.
- Human players and AI opponents share the same match.
- Players choose where to spawn before the match begins.
- Explore the open world and search for vehicle drops.
- Challenge nearby rivals by honking to start a head-to-head race.
- Win races and find drops to upgrade to faster vehicle classes.
- AI opponents roam the map, collect drops, and compete with players.
- The match progresses toward a final showdown.
- One competitor wins the match.

## Current release

**[v0.1.0 — Architecture Foundation](docs/release/0.1.0.md)**

Included:
- Initial `server-plugin/`, `client-mod/` and `shared/` structure, including BeamNG's `scripts/modScript.lua` loader.
- Minimal Lua entry points and subsystem boundaries.
- Draft versioned network message envelope.
- Initial match constants and example server configuration.
- Offline Python structural/configuration tests.
- Local Windows and Linux packaging scripts.

Not implemented yet:
- Playable lobby or spawn selection.
- BeamMP gameplay event handlers.
- Synchronized AI vehicles or AI driving.
- Vehicle drops, head-to-head races, arena contraction or final showdown.

## Match design

### 20 competitor slots

The target is 20 active competitor slots. Human players occupy available slots and AI is intended to fill the remaining slots.

| Human players | AI opponents | Total |
|---:|---:|---:|
| 1 | 19 | 20 |
| 5 | 15 | 20 |
| 10 | 10 | 20 |
| 15 | 5 | 20 |
| 20 | 0 | 20 |

**Roster invariant:** once the match starts, late joiners become spectators/queued players. They never displace an AI competitor. An AI leaves the active roster only after server-confirmed elimination or match termination. Disconnect takeover, if implemented, reuses the same competitor slot after a grace period; it does not delete unrelated bots.

### Intended match flow

1. Lobby and competitor assignment.
2. Player spawn-area selection.
3. Open-world exploration.
4. Vehicle drops and tier progression.
5. Horn-triggered head-to-head challenges.
6. AI competitors searching, upgrading and racing.
7. Elimination and arena progression.
8. Final Showdown and winner screen.

These are design goals, not currently implemented gameplay. The full player flow, garage separation, persistent statistics, match history, roster state machine and acceptance tests are specified in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md).

## Vehicle progression

Vehicles are planned to be grouped into ten tiers, from slower entry-level cars to top-class performance vehicles.

| Tier | Intended vehicle class |
|---:|---|
| 1 | Slow city and compact cars |
| 2 | Basic road cars |
| 3 | Improved everyday cars |
| 4 | Fast sports cars |
| 5 | High-performance sports cars |
| 6 | Off-road and rally vehicles |
| 7 | Supercars |
| 8 | High-end supercars |
| 9 | Hypercars |
| 10 | Top-tier vehicles |

The actual vehicle list, configurations, balancing, and tier progression will be defined separately. The initial implementation should prioritize vehicles included with BeamNG.drive to reduce dependencies on third-party vehicle mods.

## Player experience and progression

The planned mode has an in-game main menu with Play, Garage, Statistics, Match History, Settings and How to Play. The permanent garage is separate from the temporary match vehicle: players choose from a balanced starter pool, then upgrade through Car Drops during a match. Drops never overwrite the permanent garage. Career statistics are server-derived and include wins, placements, duels, eliminations, drops, survival time and distance. See [Game Design](docs/GAME_DESIGN.md) for the complete specification.

## Architecture

See **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** for the initial architecture and AI synchronization milestone.

- **`server-plugin/`** — authoritative match state, competitor roster and validation.
- **`client-mod/`** — BeamNG extension loaded through `scripts/modScript.lua`, input, UI, world presentation and AI prototypes.
- **`shared/`** — versioned network protocol and common game rules.
- **`tests/`** — offline structural and configuration checks.
- **`.github/workflows/ci.yml`** — push-to-main/manual CI: Lua 5.1 client syntax, Lua 5.3 server syntax, recursive JSON validation, protocol/config consistency and Python tests.
- **`tools/`** — local packaging scripts; CI has no scheduled runs.

The server owns official match outcomes. Client-side vehicle physics and AI synchronization are separate engineering challenges. The first AI milestone is one controlled AI vehicle observed consistently by two clients; scaling to 20 must wait until that is proven.

## Build locally

Requirements:
- Python 3.
- Windows: PowerShell (included with supported Windows versions).
- Linux: `zip` command-line utility.

Windows:

```bat
tools\build.bat
```

Linux:

```sh
chmod +x tools/build.sh
./tools/build.sh
```

The scripts run the offline tests and create:
- `dist/Resources/Server/Eliminator/` — server plugin files.
- `dist/Eliminator-client.zip` — client mod package.

These checks do not verify BeamMP runtime compatibility or multiplayer synchronization. Those require a real test server and BeamNG clients.

## Development roadmap

### Phase 1 — Project foundation
- [x] Create the initial server/client/shared project layout.
- [x] Add local packaging scripts and offline structural tests.
- [x] Define a draft versioned message envelope.
- [ ] Verify plugin loading on the target BeamMP Server build.
- [ ] Verify client extension loading in BeamNG.drive.
- [ ] Implement match lifecycle and the 20-slot competitor manager.

### Phase 2 — Spawn selection
- [ ] Create the in-game map UI.
- [ ] Add selectable spawn areas.
- [ ] Implement vehicle placement at selected locations.
- [ ] Distribute AI spawn locations.
- [ ] Add match-ready checks and countdown.

### Phase 3 — Vehicle drops
- [ ] Create a vehicle catalogue and tier configuration.
- [ ] Spawn drops at configured map locations.
- [ ] Add world and map markers.
- [ ] Implement pickup interaction.
- [ ] Add server-side pickup validation and claim locking.
- [ ] Implement synchronized vehicle replacement.

### Phase 4 — Head-to-head races
- [ ] Detect and validate horn-based challenges.
- [ ] Add accept/decline behaviour.
- [ ] Select and synchronize finish locations.
- [ ] Add race countdown and progress tracking.
- [ ] Determine winners and issue rewards.

### Phase 5 — AI competitors
- [ ] Prototype one AI competitor.
- [ ] Synchronize its vehicle for multiple clients.
- [ ] Add navigation and map exploration.
- [ ] Add drop searching and collection.
- [ ] Add AI challenge and race behaviour.
- [ ] Test progressively with 1, 3, 5, 10 and up to 20 competitors.

### Phase 6 — Match finale and polish
- [ ] Implement elimination and final-stage rules.
- [ ] Add remaining-competitor HUD.
- [ ] Add match results and winner screen.
- [ ] Balance vehicle tiers and drop frequency.
- [ ] Run full multiplayer and performance tests.

## Design principles

- **Server-authoritative outcomes:** the server decides match state, drop ownership, rewards and results.
- **Stable 20-slot match:** joining players never remove active bots; late joiners spectate or queue for the next match.
- **Shared rules:** AI and human competitors use the same progression and race rules wherever practical.
- **Vanilla-first vehicles:** start with vehicles included in BeamNG.drive.
- **Incremental testing:** prove multiplayer vehicle synchronization with a small number of AI cars before scaling toward 20.
- **Modular implementation:** keep match management, drops, races, AI and UI as separate systems.

## Inspiration and credits

BeamNG Eliminator is an independent community project inspired by the general gameplay concept of open-world vehicle elimination modes. It is not affiliated with, endorsed by, or associated with BeamNG GmbH, BeamMP, or Playground Games / Xbox Game Studios. Forza Horizon and The Eliminator are referenced only to describe the gameplay inspiration.

## Research

Browse the dated technical investigations in **[docs/research](docs/research/README.md)**. Each entry includes its date and a short description.
