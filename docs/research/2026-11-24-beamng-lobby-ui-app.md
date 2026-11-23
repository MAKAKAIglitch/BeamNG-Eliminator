# BeamNG Lobby UI App — Technical Research

**Date:** 2026-11-24  
**Scope:** Native BeamNG UI app structure and the GE Lua ↔ AngularJS event bridge used by the Eliminator lobby display.  
**Status:** Documentation-backed implementation; not yet loaded in a live BeamNG/BeamMP session.

## 1. Official UI app structure

BeamNG's UI app documentation describes apps built with AngularJS directives. The app metadata is stored in `app.json`; the directive implementation is in `app.js`; the app markup is in `app.html`; optional styling can be supplied in `app.css`, and `app.png` provides the selector image (recommended 250×120 px).

The BeamMP UI-app guide demonstrates the following integration pattern:

- Place the UI app under `ui/modules/apps/<AppName>/` in the client resource.
- Register an AngularJS directive with `angular.module('beamng.apps').directive(...)`.
- Use `templateUrl` to load the app's HTML.
- Call `bngApi.engineLua('extensions.<extension>.<function>()')` from the UI to invoke an exported GE extension function.
- Call `guihooks.trigger('EventName', payload)` from Lua.
- Subscribe to that event with `$scope.$on('EventName', ...)` in the UI directive.

Sources:
- BeamNG.drive, [Creating an app](https://documentation.beamng.com/modding/ui/app_creation/).
- BeamMP, [UI-App Creation](https://docs.beammp.com/beamng/dev/modding/ui-apps/).
- BeamNG.drive, [Extensions](https://documentation.beamng.com/modding/programming/extensions/).

## 2. Project layout

The client resource now contains:

```text
client-mod/
├── scripts/
│   └── modScript.lua
├── lua/
│   └── ge/
│       └── extensions/
│           └── eliminator.lua
└── ui/
    └── modules/
        └── apps/
            └── EliminatorLobby/
                ├── app.json
                ├── app.js
                ├── app.html
                └── app.css
```

The existing `scripts/modScript.lua` loads the `eliminator` GE extension. The client build packages all files below `client-mod/`, so the UI app is included in the BeamMP client ZIP.

## 3. Snapshot bridge

The server remains authoritative and sends versioned `match.snapshot` and `match.countdown` events. The GE extension validates the envelope before retaining the snapshot.

The UI bridge uses one namespaced Angular event, `EliminatorLobbyUpdate`:

- On a validated snapshot, Lua stores the new snapshot and triggers the UI event.
- On a validated countdown event, Lua updates the countdown and triggers the same UI event.
- When the UI app opens, it calls the exported `extensions.eliminator.requestLobbySnapshot()` function to receive the latest cached state immediately.
- When the match leaves the `starting` phase, the client clears the displayed countdown.

The UI renders exactly 20 slot positions from the server snapshot, with empty placeholders when a slot is absent. It shows player/AI/empty state, eliminated and disconnected state, spectators, match phase, roster lock state and countdown.

## 4. Deliberate scope boundary

The first lobby app is display-only. It does not send client-to-server requests and does not contain inert Ready, Leave or Spawn buttons.

The current server protocol has no implemented and validated player-facing spawn-selection or ready-request handlers. Those controls must be added only after the request message schema, server-side validation, state transition, broadcast and tests are implemented.

The app does not claim that AI competitor identities correspond to spawned or synchronized BeamNG vehicles. The server roster still contains logical AI placeholders.

## 5. Verification status

Offline checks now cover:

- Presence of all four UI app source files.
- Valid `app.json` and directive/DOM element naming consistency.
- Presence of the Lua-to-UI event bridge and initial snapshot request.
- Rendering loops for the 20 competitor slots and spectator list.
- JavaScript syntax via `node --check` and mocked Angular scope/state updates via `tests/ui/test_lobby_app.js`.
- GE extension event registration, envelope validation, UI event forwarding and unload cleanup via `tests/lua/test_client_extension.lua` (Lua 5.1).

These checks do not prove that the UI app appears in BeamNG's app selector, that BeamMP distributes the UI files correctly, or that the event bridge works in a live game. Those require a client ZIP installed through a test BeamMP server and an in-game smoke test.
