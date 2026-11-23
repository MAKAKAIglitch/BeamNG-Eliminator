# BeamMP Match Lifecycle Adapter — Integration Research

**Date:** 2026-11-24  
**Short description:** Verification of the BeamMP Server 3.x events, console-command hook, event timers and server-to-client event transport used by the first live adapter prototype.

**Research status:** Documentation-backed implementation reference. The adapter has mocked Lua tests, but has not yet been run on a live BeamMP server or verified with two BeamNG clients.

## Official references

- [BeamMP Server Scripting Reference](https://docs.beammp.com/scripting/server/latest-server-reference/)
- [BeamMP Client Scripting Reference](https://docs.beammp.com/scripting/mod-reference/)

## Verified server API used

| API/event | Use in this project |
|---|---|
| onInit / onShutdown | Initialize the match manager, register handlers and cancel the countdown timer on shutdown. |
| MP.RegisterEvent(event, functionName) | Register named global event handlers. |
| onPlayerJoin(player_id) | Add a player to the open lobby or spectator list. |
| onPlayerDisconnect(player_id) | Mark a human competitor disconnected without silently eliminating them. |
| onConsoleInput(input) | Expose namespaced server-console commands. |
| onChatMessage(player_id, player_name, message) | Provide a player-facing status command; return 1 to consume it. |
| MP.CreateEventTimer(event_name, interval_ms) | Run the match countdown tick every 1000 ms. Event timers repeat until cancelled. |
| MP.CancelEventTimer(event_name) | Stop the countdown timer after completion, explicit stop or plugin shutdown. |
| MP.GetPlayerName(player_id) | Obtain the current display name without collecting connection identifiers. |
| MP.SendChatMessage(player_id, message) | Send status and match announcements; -1 broadcasts. |
| MP.TriggerClientEventJson(player_id, event_name, table) | Send structured snapshots when available (documented since BeamMP Server 3.1.0). |
| MP.TriggerClientEvent(player_id, event_name, jsonString) | Compatibility fallback using Util.JsonEncode. |

The server reference states that onPlayerJoin occurs after authentication, connecting and mod-download/joining stages. The adapter only adds players after onPlayerJoin, when the client has entered the game.

The console adapter exposes:

- eliminator status
- eliminator lobby
- eliminator start
- eliminator stop

Starting locks the roster and starts a 10-second countdown. A one-second repeating event timer transitions the manager from starting to active after the countdown. The server owns this transition; countdown messages are informational.

## Client event contract

The official client reference documents:

- AddEventHandler(eventName, function) for receiving an event string.
- jsonDecode(data) for decoding JSON payloads.

The client extension listens for:

- eliminator:match_snapshot with envelope type match.snapshot.
- eliminator:match_countdown with envelope type match.countdown.

Both handlers reject invalid JSON, unexpected envelope types and unsupported protocol versions. The client currently stores the latest data and writes a log entry; no HUD or gameplay UI has been implemented.

## Disconnect behavior and current limits

- A disconnected human retains their existing competitor slot and active match identity.
- The snapshot exposes connection_status = disconnected.
- A lobby cannot be locked while a human competitor is disconnected.
- Reconnection using the same runtime player ID restores the existing slot.
- BeamMP runtime IDs are ephemeral. This prototype does not match a reconnect that receives a different runtime ID.
- There is no timed grace-period expiration or AI takeover yet.
- Disconnecting during an active match does not currently eliminate the competitor or replace them with AI.

## Compatibility notes

- MP.TriggerClientEventJson is documented since server 3.1.0. The adapter falls back to MP.TriggerClientEvent plus Util.JsonEncode when the JSON convenience method is absent.
- The adapter uses a 1000 ms timer, far above the documented 25 ms lower-bound caution.
- The timer is event-driven; no blocking sleep or busy loop is used.
- Server/client event payloads use protocol version 1.
- No IP address, account identifier or other connection identifier is collected or persisted.

## Verification still required

1. Load the packaged plugin on the exact target BeamMP Server version.
2. Confirm require("modules.match_manager") resolves from the packaged plugin directory.
3. Confirm all four documented event handlers register without errors.
4. Join two real BeamNG clients and verify both receive snapshots.
5. Run the countdown and confirm the server and both clients agree on the phase transition.
6. Disconnect/reconnect a player and verify the same runtime ID behavior on the actual server.
7. Confirm shutdown cancels the event timer without errors.

The mocked adapter test validates the project code against a simulated BeamMP API. It is not a substitute for these runtime checks.
