# BeamNG client mod

This directory contains the client-side BeamNG.drive extension.

## Responsibilities

- In-game HUD and spawn selection UI.
- Player input and client-to-server requests.
- Drop and race world markers.
- AI vehicle creation, navigation and control prototypes.
- Rendering synchronized competitor state received from the server.

The client mod is deliberately minimal in this first foundation release. No AI vehicle is spawned and no BeamMP event is registered yet. The exact extension lifecycle, vehicle-control APIs and multiplayer synchronization behaviour must be tested in BeamNG.drive with at least two connected clients.

## Packaging

The local build script packages this directory as a client ZIP. The ZIP preserves the directory layout under the BeamNG mod root (for example, `lua/ge/extensions/eliminator/`).
