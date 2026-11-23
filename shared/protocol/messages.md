# Network protocol

**Protocol version:** 1  
**Status:** Draft contract; no message handlers are implemented yet.

## Envelope

Every future message should use a versioned envelope:

```json
{
  "type": "client.hello",
  "version": 1,
  "request_id": "optional-correlation-id",
  "payload": {}
}
```

## Reserved message types

| Message | Direction | Purpose |
|---|---|---|
| `client.hello` | Client → Server | Announce client protocol support |
| `server.state` | Server → Client | Report authoritative match phase |
| `match.snapshot` | Server → Client | Send a validated competitor snapshot |
| `spawn.select` | Client → Server | Request a spawn selection |
| `drop.claim` | Client → Server | Request a vehicle-drop claim |
| `duel.request` | Client → Server | Request a head-to-head challenge |
| `duel.response` | Client → Server | Accept or decline a challenge |
| `race.progress` | Client → Server | Submit race progress for validation |
| `match.result` | Server → Client | Announce the authoritative result |

These names are reserved for design consistency. Payload schemas, rate limits, authorization and handlers must be specified and tested before use.

## Trust boundary

The server is authoritative for competitor slots, match phases, drop ownership, duel state, rewards and results. A client message is a request, not proof that an action happened. Client-reported positions and race progress require plausibility checks and must not be trusted blindly.
