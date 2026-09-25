---
sidebar_position: 1
---

# Introduction

Welcome to the **Template** API documentation.

This project is a Roblox game built in Luau, synced with Rojo and packaged with Wally.
Game entities are driven by a Unity-style **Behavior** system: functional classes attached to
instances via CollectionService tags, using attributes for replicated state.

## Getting started

- **Behaviors** — paired `Server<Name>` / `Client<Name>` classes extend `BehaviorBase(instance, replicator)`
  and are driven by a framework lifecycle (`onStart`, `onHeartbeat`, `onRenderStepped`, `onStepped`, `destroy`).
- **Networking** — all client/server traffic flows through one typed `Network` module.
- **Replicated state** — per-instance state replicates server to client through the shared `AttributeReplicator`.

Browse the **API** section for the documented modules, services, and hooks generated straight
from the source.
