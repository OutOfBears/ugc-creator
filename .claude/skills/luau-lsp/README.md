# luau-lsp plugin

Registers JohnnyMorganz's `luau-lsp` as a Claude Code language server so Claude can navigate
code (go-to-definition, find-references, document/workspace symbols, hover) instead of
grepping. Requires `ENABLE_LSP_TOOL=1` (set in `.claude/settings.json`).

`diagnostics` is **off** — this server is for navigation only. Lint/type gating stays with
the `/check` skill (luau-lsp's diagnostics are noisy in this `nonstrict` + generic-Component
codebase, by design).

Depends on `luau-lsp` and `rojo` being on `PATH` (both pinned in `rokit.toml`) and on the
`.luau-lsp/` cache (see `.luau-lsp/README.md`).

## Activate

The tool loads only when the plugin is loaded:

1. `/reload-plugins` (or restart Claude Code).
2. `/plugin` — confirm `luau-lsp@skills-dir` is listed. Check `/plugin errors` if it isn't.

## Verify it works (after activation)

Ask Claude to, e.g.:
- "go to the definition of `Component`" — should jump to the module, not grep.
- "find references to `ServerEvents.fire`" — should list call sites.
- "list the symbols in `PlayerService.luau`" — should return ~20 symbols.

The server was smoke-tested at setup (initialize advertised definition/references/symbols/
hover; documentSymbol returned 20 symbols from `PlayerService.luau`).

## Troubleshoot

- **Tool absent / `/plugin errors` shows it didn't start** — confirm `which luau-lsp` and
  `which rojo` resolve.
- **Navigation/types don't resolve after load** — likely the server's working directory
  isn't the project root, so the relative paths in `plugin.json` (`--base-luaurc`,
  `--definitions`, `--settings`) miss. Fix by moving those into the server's `settings` field
  (workspace-relative, resolved from the LSP `rootUri`) instead of CLI flags.
- **Engine-API hover is thin / "unknown global"** — the Roblox type cache is missing; refresh
  it per `.luau-lsp/README.md`. Cross-file navigation still works without it (via sourcemap).
