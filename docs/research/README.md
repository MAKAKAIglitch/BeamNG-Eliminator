# Research

Research notes and technical investigations for BeamNG Eliminator.

| Date | Research | Short description |
|---|---|---|
| 2026-11-23 | [The Eliminator — Gameplay and BeamMP Feasibility](2026-11-23-the-eliminator-beammp-feasibility.md) | Breakdown of the original mode's gameplay loop and feasibility of implementing shared AI competitors, drops, duels, arena contraction and Final Showdown in BeamNG + BeamMP. |
| 2026-11-23 | [BeamMP Server Plugins — Technical Research](2026-11-23-beammp-server-plugin-development.md) | Guide to BeamMP Server 3.x Lua plugins: folder layout, Lua runtime, events, player/vehicle APIs, client communication, storage, debugging, compatibility and game-mode architecture. |
| 2026-11-23 | [BeamNG Client Mod Loading](2026-11-23-beamng-client-mod-loading.md) | Verified client ZIP layout, `scripts/modScript.lua`, GE extension loading and the remaining in-game integration checks. |
| 2026-11-24 | [BeamMP Match Lifecycle Adapter — Integration Research](2026-11-24-beammp-match-adapter-integration.md) | Current official server/client event APIs, console commands, countdown timer, snapshot transport, disconnect behavior and live-server verification checklist. |

## Project documentation

- [Architecture](../ARCHITECTURE.md) — runtime boundaries, authority model and AI synchronization gate.
- [Game Design](../GAME_DESIGN.md) — player menu, garage/loadout separation, 20-slot bot-retention rules, career statistics, match history and acceptance tests.
- [v0.1.0 release notes](../release/0.1.0.md) — scope and limitations of the architecture foundation.
