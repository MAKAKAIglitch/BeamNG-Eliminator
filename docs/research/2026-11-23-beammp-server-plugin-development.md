# BeamMP Server Plugins — Technical Research

**Date:** 2026-11-23  
**Short description:** Practical guide to the BeamMP Server 3.x Lua plugin system: installation layout, Lua runtime, event lifecycle, player and vehicle APIs, client communication, persistence, debugging, compatibility, and the architecture implications for a multiplayer game mode.

**Research status:** Documentation-backed technical survey. API details below are based primarily on the current official BeamMP 3.X documentation. Community repositories are used as implementation examples, not as substitutes for the official API contract. No plugin has been built or run as part of this research.

---

## 1. The most important distinction: server plugin vs. client mod

BeamMP has two separate Lua environments:

| Component | Location | Runs where | Main responsibility |
|---|---|---|---|
| Server plugin | `Resources/Server/<PluginName>/` | Dedicated BeamMP server | Match rules, authoritative state, validation, player lifecycle, persistence, server commands |
| Client mod | ZIP in `Resources/Client/` | Each player's BeamNG.drive game | In-game UI, input, world interaction, client-side vehicle/AI operations, rendering |

A server plugin does **not** automatically execute inside BeamNG.drive. A server plugin alone cannot draw a custom HUD, read the local horn input, or directly run BeamNG's vehicle AI in the game world. Those features need a client-side mod and a defined network protocol between the client and server.

Official references:
- [Server scripting reference](https://docs.beammp.com/scripting/server/latest-server-reference/)
- [Server-side mod creation guide](https://docs.beammp.com/guides/mod-creation/server/getting-started/)
- [Client scripting reference](https://docs.beammp.com/scripting/mod-reference/)

## 2. Runtime and plugin layout

The current official server scripting reference describes the **BeamMP Server 3.X** plugin system as **Lua 5.3**. The v3.0.0 transition changed the API substantially; old pre-v3 plugins are not drop-in compatible.

Default layout:

```text
Resources/
├── Server/
│   └── Eliminator/
│       ├── main.lua
│       ├── events.lua
│       ├── match.lua
│       └── modules/
│           ├── roster.lua
│           └── persistence.lua
└── Client/
    └── EliminatorClient.zip
        ├── scripts/
        │   └── modScript.lua
        └── lua/
            └── ge/
                └── extensions/
                    └── eliminator.lua
```

Important loading rules from the official reference:

- Each server plugin gets its own directory under `Resources/Server`.
- All `.lua` files directly inside the plugin directory are loaded at server startup in **alphabetical order**.
- Top-level statements in those files execute during loading.
- Lua files in subdirectories are not auto-loaded; they can be loaded with `require()`.
- Keep one predictable entry file and put reusable modules in subdirectories. Do not depend on incidental filesystem order.
- Since server v3.1.0, edits to files in a plugin's root directory can trigger a Lua-state reload. Changes inside subdirectories trigger `onFileChanged` but do not automatically reload the state. Files created after startup are not tracked by that mechanism.

For a client mod, the ZIP is delivered to clients from `Resources/Client`; its `modScript.lua` loads the BeamNG extension. This is a separate package from the server plugin.

## 3. First server plugin

A minimal server plugin can be as small as:

```lua
-- Resources/Server/Example/main.lua

local function onPlayerJoin(playerID)
    local name = MP.GetPlayerName(playerID)
    MP.SendChatMessage(playerID, "Welcome, " .. name .. "!")
end

local function onChatMessage(playerID, playerName, message)
    if message == "!status" then
        MP.SendChatMessage(playerID, "The server plugin is running.")
        return 1 -- consume the command instead of broadcasting it
    end
end

local function onInit()
    MP.RegisterEvent("onPlayerJoin", "onPlayerJoin")
    MP.RegisterEvent("onChatMessage", "onChatMessage")
    print("[Example] Plugin initialized")
end

-- BeamMP calls registered event handlers by their global function name.
_G.onPlayerJoin = onPlayerJoin
_G.onChatMessage = onChatMessage
_G.onInit = onInit
```

The official examples commonly declare named global handler functions and register their names as strings. The explicit `_G` assignments above make that requirement visible when using local function definitions. For a first real plugin, keep the handler registration pattern simple and test it against the exact server build.

A simpler official-style pattern is:

```lua
function onInit()
    MP.RegisterEvent("onPlayerJoin", "handlePlayerJoin")
end

function handlePlayerJoin(playerID)
    MP.SendChatMessage(playerID, "Welcome!")
end
```

## 4. Event system

Handlers must be registered explicitly:

```lua
MP.RegisterEvent("onChatMessage", "handleChatMessage")
```

The second argument is the **name of a Lua function**, not a function value. Multiple handlers can be registered for an event.

### Built-in events worth knowing

| Event | Arguments | Cancellable | Use |
|---|---|---:|---|
| `onInit` | none | No | Initialize plugin state and register handlers |
| `onShutdown` | none | No | Flush persistent state and stop timers |
| `onConsoleInput` | input string | No | Add server-console commands |
| `onPlayerAuth` | name, role, isGuest, identifiers | Yes | Validate a joining player before admission |
| `postPlayerAuth` | wasRejected, reason, name, role, isGuest, identifiers | No | Observe auth result |
| `onPlayerConnecting` | playerID | No | Connection has started |
| `onPlayerJoining` | playerID | No | Client has finished downloading server mods |
| `onPlayerJoin` | playerID | No | Player has finished syncing and entered the game |
| `onPlayerDisconnect` | playerID | No | Remove player from active match state |
| `onChatMessage` | playerID, playerName, message | Yes | Chat commands and chat filtering |
| `postChatMessage` | wasSent, playerID, playerName, message | No | Observe whether a message was sent |
| `onVehicleSpawn` | playerID, vehicleID, data JSON string | Yes | Validate a vehicle spawn |
| `postVehicleSpawn` | wasSpawned, playerID, vehicleID, data | No | Observe spawn result |
| `onVehicleEdited` | playerID, vehicleID, data JSON string | Yes | Validate vehicle configuration edits |
| `postVehicleEdited` | wasAllowed, playerID, vehicleID, data | No | Observe edit result |
| `onVehicleDeleted` | playerID, vehicleID | No | Track vehicle deletion |
| `onVehicleReset` | playerID, vehicleID, data JSON string | No | Track vehicle reset/position update |
| `onVehiclePaintChanged` | playerID, vehicleID, data JSON string | No | Track paint changes |
| `onFileChanged` | path string | No | React to plugin resource file changes (v3.1.0+) |

Player connection order:

```text
onPlayerAuth
  -> onPlayerConnecting
  -> onPlayerJoining
  -> onPlayerJoin
```

Cancellable event behavior:

- Returning `1` cancels a cancellable event.
- For `onPlayerAuth`, returning a string rejects the connection with that reason; returning `1` rejects generically. The reference also documents return `2` to allow entry when the server is full.
- For `onVehicleSpawn` and `onVehicleEdited`, returning a value other than `0` cancels the action.
- For chat, returning `1` prevents the message from being broadcast.
- Do not return cancellation values from events marked non-cancellable and expect them to have an effect.

### Custom events and plugin isolation

- `MP.TriggerLocalEvent(name, ...)` invokes handlers in the current Lua state synchronously and returns their results.
- `MP.TriggerGlobalEvent(name, ...)` invokes handlers across plugin states asynchronously. Its result is a future-like object with `:IsDone()` and `:GetResults()`.
- The global event system is useful for loose integration, but a core game mode should not depend on unrelated plugins being installed.
- Separate plugin Lua states are not ordinary shared modules. Use local events, global events, or an explicit shared-state configuration only when needed.

## 5. Event timers and execution model

The v3 system uses event timers rather than the old pre-v3 `CreateThread` model:

```lua
local function tick()
    -- Small, bounded server-side work.
end

MP.RegisterEvent("EliminatorTick", "tick")
MP.CreateEventTimer("EliminatorTick", 1000) -- milliseconds
```

Important details:

- The interval is in **milliseconds**.
- Intervals below 25 ms are explicitly discouraged by the reference.
- Prefer a small number of shared timers over many independent timers.
- The default `MP.CallStrategy.BestEffort` skips queuing a new invocation if a previous handler is still taking too long.
- `MP.CallStrategy.Precise` queues every interval and can build up a backlog; use it only when exact scheduling is genuinely required.
- `MP.CancelEventTimer(eventName)` cancels timers for that event; one final callback may still occur.
- Event handlers execute synchronously in the Lua state. Keep each handler short and bounded.
- `MP.Sleep()` blocks execution in the current Lua state; the docs warn against sleeping more than 500 ms when event handlers are registered. Do not build gameplay loops around long sleeps or infinite loops.

For this project, one coarse match tick (for example, 500–1000 ms) is a better starting point than a high-frequency timer. Client vehicle physics and position packets already operate at a different cadence; the match manager should process discrete decisions, not attempt to simulate vehicle physics on the server.

## 6. Player API

Useful documented functions:

| Function | Meaning |
|---|---|
| `MP.GetPlayerCount()` | Number of connected players |
| `MP.GetPlayers()` | Map of `[playerID] = playerName` |
| `MP.GetPlayerName(playerID)` | Name, or empty string if not found |
| `MP.GetPlayerIDByName(name)` | ID, or -1 if not found |
| `MP.GetPlayerIdentifiers(playerID)` | Identifier table (BeamMP ID, IP, optional Discord); nil if not found |
| `MP.GetPlayerRole(playerID)` | Backend role or nil |
| `MP.IsPlayerConnected(playerID)` | Whether connection is fully established |
| `MP.IsPlayerGuest(playerID)` | Whether the player is a guest |
| `MP.DropPlayer(playerID, reason?)` | Disconnect a player |

Player server IDs are runtime identifiers, not permanent competitor IDs. Treat them as ephemeral: remove mappings on disconnect and never persist a server ID as a player's durable identity. For match state, assign an internal competitor ID and maintain a temporary mapping to the current player ID.

**Privacy note for plugin authors:** `MP.GetPlayerIdentifiers` can expose IP and account identifiers. A gameplay plugin should not collect or log those fields unless a specific, justified server feature requires them. The Eliminator match system only needs the transient server player ID, display name, and match state. Do not put real-world personal data in logs or persisted match files.

## 7. Vehicle API and its limitations

The official server-side API documents:

- `MP.GetPlayerVehicles(playerID)` — returns a map of vehicle IDs to raw JSON data strings, or nil if the player has no vehicles / was not found.
- `MP.GetPositionRaw(playerID, vehicleID)` — returns position, rotation, velocity, rotational velocity, timing and ping data, plus an error string. Position/velocity values are indexed tables; rotation has four values.
- `MP.RemoveVehicle(playerID, vehicleID)` — removes a vehicle belonging to a player.

The server event payloads for vehicle spawn/edit/reset are JSON strings. Parse and validate them; do not assume they are already Lua tables.

**Critical limitation:** the documented server API lists vehicle inspection and removal, but does not document a general server-side `MP.SpawnVehicle`, server-side AI driving command, or a server-side physics controller. Do not design the mode around such functions unless a specific server release or separate extension proves they exist. Vehicle creation, AI navigation, input and world-space effects are BeamNG client/game-side work. The server should authorize the action and distribute the resulting game event/state through the client bridge.

This distinction is the central technical risk for AI competitors: a Lua server plugin can track an AI competitor as match data, but that alone does not create a shared, drivable AI vehicle visible to every client.

## 8. Server-to-client and client-to-server communication

### Server to client

The current reference documents:

```lua
MP.TriggerClientEvent(playerID, eventName, dataString)
MP.TriggerClientEventJson(playerID, eventName, luaTable)
```

Use player ID `-1` to broadcast. Since v3.1.0 the functions return a success boolean and an error string; a failed send to a disconnected/unknown player should not be retried blindly.

Prefer `MP.TriggerClientEventJson` for structured gameplay messages so the server can send a Lua table and BeamMP handles JSON encoding.

### Client to server and client-side handlers

The official client scripting reference documents:

- `TriggerServerEvent("eventName", "data")` — sends a string payload to the server Lua environment.
- `TriggerClientEvent("eventName", "data")` — dispatches a local client event.
- `AddEventHandler("eventName", function)` — registers a client event handler receiving a string.

The protocol should therefore use named events and JSON-encoded string payloads, with explicit versioning and validation. Example message shape:

```json
{
  "protocol": 1,
  "requestId": "drop-claim-unique-token",
  "action": "claim_drop",
  "dropId": "drop-0042"
}
```

Treat every client message as untrusted input. A modified client can send arbitrary values; never trust a client-reported winner, vehicle tier, drop reward, position, or elimination result without server-side validation. The client asks; the server decides.

Recommended protocol rules:

1. Include a protocol version and message/action name.
2. Validate types, lengths, ranges and allowed action names.
3. Resolve the sender from the server-provided player ID, never from a player ID supplied inside JSON.
4. Check that the player is connected, alive, in the correct match phase and allowed to perform the action.
5. Use unique request IDs / idempotency keys for one-time actions such as drop claims.
6. Rate-limit client requests.
7. Reply only to the requesting player when the response is private; broadcast only public state.
8. Keep authoritative state on the server and send clients snapshots or deltas.

## 9. JSON, files, persistence and HTTP

The official server API exposes a `Util` JSON helper family and an `FS` filesystem helper family. The documented FS API includes:

- Checks: `FS.Exists`, `FS.IsDirectory`, `FS.IsFile`.
- Operations: `FS.CreateDirectory`, `FS.Remove`, `FS.Rename`, `FS.Copy`, `FS.ListFiles`, `FS.ListDirectories`.
- Paths: `FS.GetFilename`, `FS.GetExtension`, `FS.GetParentFolder`, `FS.ConcatPaths`.

The documented FS reference does **not** list a general `FS.ReadFile` or `FS.WriteFile` function. Do not invent those APIs. The reference also documents `Http.CreateConnection(host, port)` and a connection `:Get(path, headers)` method; that is an outbound HTTP GET facility, not a general database.

The server API reference contains JSON encode/decode helpers under `Util`; use the exact names and return behavior from the installed server's current API reference. In vehicle examples, `Util.JsonDecode` is used to parse vehicle JSON.

Persistence options to investigate in a prototype:

- A small JSON state file using a file-I/O mechanism actually supported by the target server build.
- A database library packaged with the plugin, after checking its native dependencies, OS support and license.
- A separate local service/database, only if the operational complexity is justified.

Do not assume a third-party plugin's bundled SQLite/MySQL library is portable or safe to copy. Check its license, native binaries, target OS, server version, and maintenance status. For the first game-mode prototype, keep match state in memory and prove event flow first; persistence can follow once the supported file/database mechanism is selected.

## 10. Server console commands

Register `onConsoleInput` and parse a namespaced command prefix, for example `elim status`, `elim start`, `elim stop`. Do not claim generic names such as `status` or `print` that may collide with server commands or other plugins.

```lua
local function onConsoleInput(input)
    local command, rest = input:match("^(%S+)%s*(.*)$")
    if command ~= "elim" then
        return
    end

    if rest == "status" then
        print("[Eliminator] status requested")
        return ""
    end
end

MP.RegisterEvent("onConsoleInput", "onConsoleInput")
```

Test exact console return behavior on the target server version before relying on it for command output. A command handler should do minimal parsing and call the same match functions used by gameplay events.

## 11. Debugging and development workflow

Officially documented debugging facilities:

- `print(...)` writes values (including tables) to the server console with a timestamp/LUA prefix.
- Enter a plugin Lua state from the server console with `lua PluginName`; leave with `:exit` on v3.1.0+ (older instructions mention `exit()`).
- TAB autocomplete is documented since v3.1.0.
- `status` in the normal server console reports Lua statistics, including event timers and handlers.
- `MP.GetServerVersion()` returns major/minor/patch.
- `MP.GetStateMemoryUsage()` and `MP.GetLuaMemoryUsage()` can help inspect Lua memory use.

Suggested test ladder:

1. Start a local private BeamMP server with the exact server binary intended for deployment.
2. Load a tiny plugin that prints its initialization and registers `onPlayerJoin`.
3. Verify chat interception and a namespaced console command.
4. Verify client-to-server event delivery using a client mod.
5. Verify server-to-client targeted and broadcast messages.
6. Verify JSON payload round-trips and malformed input handling.
7. Verify join/disconnect cleanup and player-ID reuse.
8. Verify vehicle spawn/edit/reset/delete event ordering and vehicle data parsing.
9. Measure timer execution and Lua memory with multiple clients.
10. Only then build the match state machine and test with multiple players.

Never call a feature tested merely because its API is documented. These steps are a proposed test plan, not completed tests.

## 12. Architecture recommendations for BeamNG Eliminator

A sensible division of responsibilities is:

### Server plugin — authority and match rules

- `MatchManager`: lobby, countdown, match phases, final showdown.
- `RosterManager`: 20 competitor slots, human/AI identities, reconnect/disconnect transitions.
- `DropManager`: drop definitions, availability, one-time claim locks, reward decisions.
- `DuelManager`: challenge validation, race IDs, countdown, finish claims, result decisions.
- `ArenaManager`: current safe-zone state and phase transitions.
- `EliminationManager`: alive/eliminated status and final competitor count.
- `ProtocolHandler`: validate client requests and emit snapshots/deltas.
- `Persistence`: save only durable configuration/statistics once a supported storage mechanism is proven.

### Client mod — game-world operations

- HUD, map, drop markers and route markers.
- Horn/input detection and local interaction prompts.
- BeamNG AI creation, navigation and vehicle-side control experiments.
- Visual effects, vehicle replacement UI and sound.
- Client request/response handlers.

### Authority model

The server owns match facts: competitor slots, phase, drop availability, claim ownership, duel status, eliminations and winner. Clients may report observations (for example, reaching a finish area), but the server validates them against server-observed positions and the current race state. For a client-controlled AI prototype, define an explicit controller lease and failure/reassignment behavior; do not silently treat one player's local AI as globally synchronized.

### First proof of concept

Before implementing the 20-slot match, build the smallest end-to-end slice:

1. One server plugin and one client ZIP.
2. Server broadcasts a versioned match-state message.
3. Client displays a simple status indicator.
4. Client sends a test request to the server.
5. Server validates sender and phase, then replies.
6. Two real clients receive the same server-authoritative state.
7. Separately prototype one AI vehicle and prove that both clients see consistent position, motion and lifecycle.

The seventh step is a separate technical gate. The server event API alone does not prove that synchronized AI vehicles are possible.

## 13. Community implementation examples and popularity snapshot

Repository metrics below were read from the GitHub repository API on **2026-11-23**. Stars are a rough visibility signal, not proof of code quality or compatibility.

| Repository | Stars | Last pushed (API) | License | What it is useful for |
|---|---:|---|---|---|
| [BeamMP/BeamMP-Server](https://github.com/BeamMP/BeamMP-Server) | 216 | 2026-09-23 | AGPL-3.0 | Authoritative server source and implementation details |
| [BeamMP/BeamMP](https://github.com/BeamMP/BeamMP) | 535 | 2026-11-13 | AGPL-3.0 | Official client mod/network bridge source |
| [boubouleuh/Nickel-BeamMP-Plugin](https://github.com/boubouleuh/Nickel-BeamMP-Plugin) | 21 | 2026-10-23 | MIT | Larger plugin architecture, commands, roles and database approach |
| [ServerGuardian/BeamMP_Plugin](https://github.com/ServerGuardian/BeamMP_Plugin) | 0 | 2026-11-13 | Not stated in repository metadata | Modern server/client event protocol example; README says tested in a fake BeamMP environment, not yet on a real server |

Notes:

- The official repositories are the primary source of truth. Their licenses apply to their code; do not copy implementation code into this project without reviewing license obligations.
- Nickel has meaningful project history (368 commits shown on its repository page) and is a useful architecture reference, but it is a moderation plugin, not proof of the exact gameplay APIs required here.
- ServerGuardian demonstrates a versioned server/client event protocol and validation patterns. Its README explicitly distinguishes fake-environment testing from real-server testing; treat it as a design example, not a verified production compatibility guarantee.
- A repo's stars, recent activity or commit count do not establish security. Review source, dependencies, release artifacts and license before running anything.

## 14. Known unknowns and explicit engineering risks

1. **AI vehicle synchronization:** no official server-side AI-driving API is documented. Must be prototyped in BeamNG clients and BeamMP networking.
2. **Server-created world entities:** the documented server API does not establish a general server-side vehicle spawn/physics API.
3. **Persistent storage:** the official FS helper list does not document direct file read/write. Select and test an actual storage mechanism.
4. **Client message trust:** a client can forge requests. Server-side validation is mandatory.
5. **Position trust and update cadence:** `MP.GetPositionRaw` exposes position packets, but acceptable freshness, interpolation and exploit resistance need measurement.
6. **20 competitors:** the server plugin can maintain 20 logical competitor records; that does not mean 20 physical AI vehicles can be synchronized or simulated efficiently.
7. **Version drift:** the reference is for 3.X and contains features annotated as introduced in 3.0.2 or 3.1.0. Query `MP.GetServerVersion()` and test against the actual deployment binary.

## 15. Sources

### Official BeamMP documentation

- [Server Scripting Reference — BeamMP Server 3.X](https://docs.beammp.com/scripting/server/latest-server-reference/)
- [Server-Side API Reference](https://docs.beammp.com/API%20documentation/Server-Side/)
- [Multiplayer Mod Creation — Server Side](https://docs.beammp.com/guides/mod-creation/server/getting-started/)
- [Client Scripting Reference](https://docs.beammp.com/scripting/mod-reference/)
- [Development Environment Setup](https://docs.beammp.com/guides/beammp-dev/beammp-dev/)

### Official source repositories

- [BeamMP-Server](https://github.com/BeamMP/BeamMP-Server)
- [BeamMP client mod](https://github.com/BeamMP/BeamMP)

### Community implementation examples

- [Nickel BeamMP Plugin](https://github.com/boubouleuh/Nickel-BeamMP-Plugin)
- [ServerGuardian BeamMP Plugin](https://github.com/ServerGuardian/BeamMP_Plugin)
- [BeamMP server plugin topic](https://github.com/topics/beammp-server)
- [BeamMP Lua topic](https://github.com/topics/beammp?l=lua)

---

**Conclusion:** BeamMP server plugins are Lua 5.3 modules loaded into isolated server-side Lua states. They are well suited to authoritative match logic, player lifecycle, chat/console integration, validation and state distribution. They are not a replacement for a BeamNG client mod: visual UI, input and AI vehicle behavior must be implemented in the game client and synchronized through the event bridge. For BeamNG Eliminator, the next engineering task should be a minimal two-client server/client protocol prototype, followed by a separate shared-AI-vehicle experiment.
