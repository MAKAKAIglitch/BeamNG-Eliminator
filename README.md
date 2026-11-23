# BeamNG Eliminator

**A 20-competitor automotive battle royale for BeamNG.drive, powered by BeamMP.**

BeamNG Eliminator is a planned multiplayer game mode inspired by the open-world elimination-racing format popularized by *The Eliminator* in Forza Horizon. It brings the idea to BeamNG.drive: explore a large map, find better vehicles, challenge rivals, survive the match, and win the final race.

The project is intended to support **exactly 20 active competitors per match**, combining human players with AI-controlled opponents.

> **Project status:** Concept and planning. The features below describe the intended design; they are not implemented or verified yet.

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

## Match flow

### 1. Lobby and 20 competitor slots

When a player joins, they enter the match lobby. The match manager maintains 20 active competitor slots.

| Human players | AI opponents | Total |
|---:|---:|---:|
| 1 | 19 | 20 |
| 5 | 15 | 20 |
| 10 | 10 | 20 |
| 15 | 5 | 20 |
| 20 | 0 | 20 |

AI fills the slots that are not occupied by human players. If a human player disconnects, the match manager can replace that competitor with AI according to the current match state. If a human joins while an AI slot is available, the system can convert that slot to a human competitor.

The exact rules for late joining, eliminated players, and spectator mode will be finalized during implementation. The 20-slot target refers to active competitors, not necessarily the number of connected human clients.

### 2. Choose a spawn location

Before the match starts, players see an in-game map and select their preferred spawn area.

Potential areas include:

- City districts
- Mountain roads
- Forests
- Desert areas
- Industrial zones
- Countryside and highways

The spawn system distributes competitors across the map to avoid placing everyone in one location. AI opponents receive spawn locations automatically.

After selection, the player's vehicle is placed at the chosen location. A countdown begins once the match is ready.

### 3. Explore the world

At the start, competitors receive vehicles from the entry-level class. They can then:

- Drive freely around the map.
- Search for vehicle drops.
- Look for rivals to challenge.
- Avoid stronger competitors.
- Choose routes based on terrain and vehicle capabilities.

### 4. Vehicle drops and upgrades

Vehicle drops are special locations containing replacement vehicles. They are a central progression mechanic.

A drop may be marked by:

- A visible beacon or light column.
- Smoke or another world-space effect.
- A map marker.
- A vehicle tier indicator.

A competitor drives to a drop and interacts with it to claim the vehicle. The current vehicle is then replaced with the awarded vehicle.

The drop system is intended to include:

- A configurable vehicle catalogue.
- Vehicle tiers and progression rules.
- Spawn locations and drop timing.
- A clear visual marker for available drops.
- Server-side ownership and pickup validation.
- AI logic for locating and collecting drops.

A drop must have a single authoritative claim: two competitors must not be able to receive the same vehicle from one drop.

### 5. Head-to-head challenges

A player can approach another competitor and use the horn to issue a challenge.

Intended flow:

1. The game detects a valid nearby challenge.
2. The other competitor accepts or declines, subject to match rules.
3. The match system selects a finish point.
4. Both competitors receive the route or destination marker.
5. A countdown starts the race.
6. The first competitor to reach the finish wins.
7. The winner receives the configured reward, such as an upgrade to a higher vehicle tier.

Head-to-head races should support human-versus-human, human-versus-AI, and AI-versus-AI matchups.

### 6. AI competitors

AI opponents should be active competitors rather than decorative traffic.

Planned behaviours:

- Navigate roads and off-road areas.
- Explore the map.
- Search for vehicle drops.
- Collect better vehicles.
- Detect and challenge nearby competitors.
- Accept and participate in head-to-head races.
- Progress through the match and be eliminated under the same rules as human competitors.

The goal is to keep matches populated and interesting even when only a few human players are online.

### 7. Final showdown

As the match progresses, the active competitor count decreases. The final stage brings the remaining competitors into a decisive race.

The final rules, route selection, and elimination conditions will be tuned during development. The intended result is one clear match winner.

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

## Technical direction

### Planned technologies

- **BeamNG.drive** — vehicle physics, world simulation, AI and in-game Lua extensions.
- **BeamMP** — multiplayer connectivity and synchronization.
- **Lua** — gameplay logic, client-side UI, vehicle interactions and server scripts.
- **BeamMP Server Lua API** — server-side match state and validation.

### High-level architecture

**Server-side match manager**
- Maintains match state and competitor slots.
- Tracks human players and AI competitors.
- Controls match phases and elimination state.
- Owns drop availability and pickup claims.
- Validates challenge and race results.
- Decides rewards and vehicle progression.

**Client-side gameplay**
- Displays the spawn selection map and HUD.
- Shows drop and destination markers.
- Handles player interactions.
- Sends gameplay requests to the server.
- Displays challenges, countdowns and results.

**AI and vehicle synchronization**
- Creates and controls NPC vehicles.
- Implements navigation, drop-seeking and challenge behaviour.
- Synchronizes NPC state so all participants see consistent opponents.
- Handles AI ownership and recovery if the controlling client disconnects.

The exact network authority model for AI vehicles is an important engineering task. BeamNG vehicle physics normally runs in game clients, so the project must test how AI control and vehicle state can be reliably shared through BeamMP. A possible prototype is to designate an AI controller client while keeping match decisions and rewards server-authoritative. This is a design option, not an established BeamMP feature.

## Development roadmap

### Phase 1 — Project foundation
- [ ] Create the mod structure and BeamMP integration.
- [ ] Implement match lifecycle and match states.
- [ ] Add the 20-slot competitor manager.
- [ ] Add AI slot filling and player join/leave handling.
- [ ] Define server/client message contracts.

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
- **Consistent 20-slot match:** maintain 20 active competitor slots using human players and AI.
- **Shared rules:** AI and human competitors use the same progression and race rules wherever practical.
- **Vanilla-first vehicles:** start with vehicles included in BeamNG.drive.
- **Incremental testing:** prove multiplayer vehicle synchronization with a small number of AI cars before scaling toward 20.
- **Modular implementation:** keep match management, drops, races, AI and UI as separate systems.

## Project goal

Build a complete open-world automotive battle royale for BeamNG.drive: a persistent-feeling 20-competitor match with vehicle drops, progression, horn-triggered duels, AI rivals and a final race.

**20 competitors. One map. Better cars. Head-to-head battles. One winner.**

## Inspiration and credits

BeamNG Eliminator is an independent community project inspired by the general gameplay concept of open-world vehicle elimination modes. It is not affiliated with, endorsed by, or associated with BeamNG GmbH, BeamMP, or Playground Games / Xbox Game Studios. Forza Horizon and The Eliminator are referenced only to describe the gameplay inspiration.
