# BeamNG Client Mod Loading — Technical Research

**Date:** 2026-11-23  
**Scope:** BeamNG.drive GE extension loading and BeamMP client ZIP packaging.  
**Status:** Documentation review; no game client was launched during this research.

## 1. Correct BeamMP client resource layout

BeamMP's multiplayer mod creation guide documents a client resource as a ZIP stored in the server's `Resources/Client/` directory. The ZIP contains:

```text
Eliminator-client.zip
├── scripts/
│   └── modScript.lua
└── lua/
    └── ge/
        └── extensions/
            └── eliminator.lua
```

The BeamMP guide states that the server sends client ZIPs to players and that BeamNG reads `modScript.lua` to determine which extension to load.

## 2. modScript loader

The official BeamMP guide shows this minimal loader pattern:

```lua
load('examplePlugin')
setExtensionUnloadMode('examplePlugin', 'manual')
```

For this project, the extension name is `eliminator`, so the client mod uses:

```lua
load("eliminator")
setExtensionUnloadMode("eliminator", "manual")
```

The corresponding GE extension file is `lua/ge/extensions/eliminator.lua`.

## 3. GE extension contract

BeamNG's extension documentation describes an extension as a Lua file that returns a table. Common lifecycle hooks include `onExtensionLoaded` and `onExtensionUnloaded`. The extension is explicitly loaded through the extension system; defining a file alone does not guarantee that it is active.

The initial project extension returns a module table and implements only lifecycle logging. It does not access vehicle state, spawn vehicles, or register BeamMP network events.

## 4. Server/client separation

- Server plugin: `Resources/Server/Eliminator/`, extracted directory with the server entry point and modules.
- Client resource: `Resources/Client/Eliminator-client.zip`, kept as a ZIP and delivered to game clients.
- Server Lua and client GE Lua run in different environments and must communicate through an explicitly defined protocol.

The project build scripts therefore produce two separate artifacts rather than one combined package.

## 5. Project implementation decisions

- Use `client-mod/scripts/modScript.lua` as the client loader.
- Use `client-mod/lua/ge/extensions/eliminator.lua` as the GE extension entry point.
- Keep helper modules under `client-mod/lua/ge/extensions/eliminator/`.
- Keep the BeamMP server plugin under `server-plugin/`.
- Package the client directory contents at the root of the client ZIP.
- Do not mark the client mod as runtime-verified until it has been installed and loaded in BeamNG.drive through a BeamMP server.

## 6. Verification still required

This research validates the documented folder and loading contract, not runtime behaviour. The next integration checks are:

1. Start the target BeamMP Server build with the plugin folder installed.
2. Connect a BeamNG client and confirm the client ZIP is delivered.
3. Confirm `modScript.lua` loads the `eliminator` extension.
4. Confirm extension load/unload messages appear in the BeamNG log.
5. Repeat with a second client before implementing multiplayer state.

## Sources

- BeamMP, [Server-side and client-side mod creation guide](https://docs.beammp.com/guides/mod-creation/server/getting-started/).
- BeamNG.drive, [Lua extensions documentation](https://www.docs.beamng.com/modding/programming/extensions/).
