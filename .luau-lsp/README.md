# luau-lsp local cache

Supports the `luau-lsp` Claude Code plugin (`.claude/skills/luau-lsp/`), which gives Claude
code navigation (go-to-definition, find-references, symbols, hover) over the Luau source.

- `settings.json` — tracked. Tells luau-lsp to auto-generate the rojo sourcemap and use the
  Roblox platform. This is what makes cross-file navigation work.
- `globalTypes.d.luau`, `api-docs.json` — **gitignored** (machine-generated Roblox API types,
  ~7MB). They enrich hover/types for engine APIs. Navigation still works without them.

## Refresh the Roblox types (after a fresh clone, or when Roblox updates)

The luau-lsp VS Code extension keeps an up-to-date copy. Re-copy it:

```bash
CACHE="$HOME/Library/Application Support/Code/User/globalStorage/johnnymorganz.luau-lsp"
cp "$CACHE/globalTypes."*".d.luau" .luau-lsp/globalTypes.d.luau
cp "$CACHE/api-docs.json"          .luau-lsp/api-docs.json
```

If the files are missing, luau-lsp just warns and continues — navigation via the sourcemap
is unaffected; only engine-API hover/type detail is reduced.
