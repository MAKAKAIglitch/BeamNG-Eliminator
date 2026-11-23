# Architecture

## Components

| Component | Runtime | Authority |
|---|---|---|
| `server-plugin/` | BeamMP Server Lua | Match state, roster, validation and results |
| `client-mod/` | BeamNG.drive Lua/UI | Input, presentation, vehicle and AI prototypes |
| `shared/` | Source/configuration | Versioned protocol and common rules |
| `tests/` | Local Python 3 | Offline structural and configuration checks |

## Authority model

The server owns the official match state. Clients send requests; the server validates them and broadcasts accepted state changes. Client-side physics and AI vehicle control are separate engineering problems and must be verified in multiplayer before being treated as synchronized gameplay.

## AI synchronization gate

The first AI milestone is not "20 bots". It is one AI-controlled vehicle observed consistently by two clients. The prototype must establish:

1. Which client or runtime owns the vehicle simulation.
2. How vehicle state is replicated to other clients.
3. What happens when the controlling client disconnects.
4. How server-side match identity maps to the client-side vehicle.
5. Whether control remains stable under latency and packet loss.

Only after this gate passes should the project scale to 3, 5, 10 and 20 competitors.

## Build outputs

- Server plugin: `dist/Resources/Server/Eliminator/`
- Client mod: `dist/Eliminator-client.zip`

Builds are local. This repository does not add scheduled GitHub Actions workflows.
