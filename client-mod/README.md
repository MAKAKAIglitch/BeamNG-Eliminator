# BeamNG client mod

This directory contains the client-side BeamNG.drive extension delivered by BeamMP as a ZIP file.

## Loading

- `scripts/modScript.lua` loads the `eliminator` GE extension.
- `lua/ge/extensions/eliminator.lua` is the extension entry point.
- `lua/ge/extensions/eliminator/` contains internal extension modules.

The modScript follows the BeamMP client-mod creation guide. The extension itself is intentionally minimal in this foundation release.

## Responsibilities

- In-game HUD and spawn selection UI.
- Player input and client-to-server requests.
- Drop and race world markers.
- AI vehicle creation, navigation and control prototypes.
- Rendering synchronized competitor state received from the server.

No AI vehicle is spawned and no BeamMP event is registered yet. Vehicle-control APIs and multiplayer synchronization must be tested in BeamNG.drive with at least two connected clients.

## Packaging

The local build script packages the contents of this directory as `Eliminator-client.zip`. The ZIP preserves the BeamNG mod layout at its root, including `scripts/modScript.lua` and `lua/ge/extensions/eliminator.lua`.
