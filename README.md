<h1 align="center">Template</h1>

<p align="center">
  A generic Roblox game template — reusable infrastructure with no gameplay baked in.
</p>

---

## 🎮 About

This is a starting-point template for Roblox games. It ships the reusable infrastructure a new
project needs — a component system, typed networking, replicated state, a React UI layer, and a
library of VFX, camera, and math utilities — without any game-specific mechanics. Clone it, then
build your gameplay on top as paired Server/Client components and long-lived Services/Controllers.

## 🛠️ Tech stack

- **[Luau](https://luau.org/)** — game logic across server, client, and shared code.
- **[Rojo](https://rojo.space/)** — syncs the `src/` tree into a Roblox place and serves live
  changes to Studio.
- **[Wally](https://wally.run/)** — package manager for Roblox dependencies.
- **[Rokit](https://github.com/rojo-rbx/rokit)** — pins and installs the project toolchain.
- **[Lune](https://lune-org.github.io/docs)** — standalone Luau runtime for project scripts.
- **[React (jsdotlua)](https://github.com/jsdotlua) + [Charm](https://github.com/littensy/charm)**
  — UI layer under `src/interfaces`.

Game entities are modeled as **paired Server/Client components** registered through an in-repo
Component system, with long-lived `Service`/`Controller` systems driven by a shared `Loader`.
See [`CLAUDE.md`](CLAUDE.md) for the full architecture and conventions.

## 📋 Prerequisites

- [Roblox Studio](https://create.roblox.com/) with the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/#installing-the-roblox-studio-plugin) installed.
- [Rokit](https://github.com/rojo-rbx/rokit) — the toolchain manager. Everything else (Rojo,
  Wally, StyLua, Selene, luau-lsp, Lune) is pinned in [`rokit.toml`](rokit.toml) and installed
  by Rokit.

## ⚙️ Setup

Install the pinned toolchain, then install packages and generate the sourcemap and package
types:

```bash
rokit install
lune run wally-install
```

`lune run wally-install` runs `wally install`, regenerates `sourcemap.json`, and writes Wally
package type definitions — run it again whenever dependencies in [`wally.toml`](wally.toml)
change.

## 🚀 Build & run

Live-sync against Studio (the usual development loop): start the Rojo server, then connect
from the Rojo Studio plugin.

```bash
rojo serve
```

Build a standalone place file:

```bash
rojo build default.project.json -o build.rbxlx
```

Regenerate the sourcemap (used by luau-lsp; also refreshed by `wally-install`):

```bash
rojo sourcemap default.project.json -o sourcemap.json
```

## 📁 Project structure

Rojo mounts the source tree per [`default.project.json`](default.project.json):

```
src/
├── Server.server.luau     # Server entry point (boots Services via Loader)
├── Client.client.luau     # Client entry point (boots Controllers via Loader)
├── server/                # → ServerScriptService.Server — server-only logic
│   ├── Components/         #   Server<Name> entity components
│   ├── Services/           #   long-lived server systems
│   └── Modules/, Data/     #   server helpers and tunables
├── client/                # → ReplicatedStorage.Client — client-only logic
│   ├── Components/          #   Client<Name> entity components
│   ├── Controllers/         #   long-lived client systems
│   └── Modules/
├── shared/                # → ReplicatedStorage.Shared — runs on both sides
│   ├── Modules/             #   utilities (Component, Network, Maid, Loader, …)
│   └── Components/, Data/
└── interfaces/            # → ReplicatedStorage.Interfaces — React UI (Views, Components, Hooks, Stories)
```

Networking always goes through the shared `Network` module — never raw `RemoteEvent`s.
Replicated per-entity state lives in component `state` (via `AttributeReplicator`), and
tunable constants live in `Data/` modules rather than scattered at file tops.

## 🧪 Development workflow

This repo has no automated test framework — the static toolchain is the verification harness.
Run it on the files you changed before considering a task done:

```bash
selene src/                # linter — must be clean
stylua --check src/        # format check — must be clean (apply with `stylua src/`)
luau-lsp analyze ...       # type check — advisory (see CLAUDE.md §4 for flags)
```

In Claude Code, the `/check` skill runs this gate with the correct flags and scoping.
[`CLAUDE.md`](CLAUDE.md) is the authoritative contributor guide — coding conventions, the
Component system, reuse index, and the definition of done.

## 🤖 AI quick context

For Copilot and AI-assisted work, start here:

- [`CLAUDE.md`](CLAUDE.md) — canonical architecture, coding conventions, and definition of done
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — branch/commit conventions and PR expectations
- [`.github/copilot-instructions.md`](.github/copilot-instructions.md) — Copilot guidance and review priorities

## 📚 Documentation

API docs are generated from inline [Moonwave](https://eryn.io/moonwave/) doc comments and
published to GitHub Pages by [`.github/workflows/docs.yml`](.github/workflows/docs.yml) on
every push to `main`:
