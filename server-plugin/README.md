# BeamMP server plugin

This directory contains the BeamMP server-side part of BeamNG Eliminator.

## Responsibilities

- Own match phases and authoritative match state.
- Maintain the 20 competitor slots.
- Validate player requests, drop claims, duels and match results.
- Coordinate client notifications through the documented BeamMP network bridge.

The server plugin does **not** create or drive BeamNG vehicles. The BeamMP Server Lua API research did not establish a general server-side vehicle-spawn or AI-driving API. Vehicle creation and AI control must be prototyped in the client mod and tested across multiple clients.

## Layout

- `main.lua` — single root entry point loaded by BeamMP.
- `modules/` — explicitly loaded internal modules.
- `config/config.example.json` — documented starter configuration.

Only the entry point is placed in the plugin root. Keep implementation modules in subdirectories and load them explicitly, rather than relying on root-level script load order.

## Installation

Copy the contents of the build output's `Resources/Server/Eliminator/` directory into the BeamMP server's `Resources/Server/Eliminator/` directory, then restart the server.

This scaffold is not yet a playable plugin. Confirm the target BeamMP Server version and validate all API signatures in a local test server before implementing event handlers.
