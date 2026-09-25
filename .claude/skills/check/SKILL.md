---
name: check
description: Run the project quality gate (selene + stylua + luau-lsp) on the files you changed. Use before declaring any code task done, after editing .luau files, or when the user says "check", "verify", "lint", or "is this clean?". This repo has no automated tests — this static toolchain IS the verification loop.
---

# Quality gate

The verification harness for this repo. Run it on **your changed files only** — the
working tree has pre-existing lint/format/type debt elsewhere, and you clean up only your
own mess (CLAUDE.md §3).

## Steps

1. **Find the files you changed** (staged + unstaged + untracked, `src/**.luau` only):

   ```bash
   files=$(git status --porcelain | awk '{print $2}' | grep -E '^src/.*\.luau$')
   [ -z "$files" ] && echo "no changed .luau files — nothing to check" || echo "$files"
   ```

   Pass the list with `echo "$files" | xargs <tool>` — **never** bare `$files`. This repo's
   shell is zsh, which does not word-split unquoted variables, so `selene $files` sends all
   paths as one argument and fails. `xargs` splits correctly on every shell.

2. **Regenerate the sourcemap** (luau-lsp needs it current):

   ```bash
   rojo sourcemap default.project.json -o sourcemap.json
   ```

3. **Run the checks on your files:**

   ```bash
   echo "$files" | xargs selene
   echo "$files" | xargs stylua --check
   ```

   For luau-lsp you MUST pass the Roblox type definitions and the project `.luaurc`, or it
   reports every Roblox global (`task`, `Instance`, `Vector3`, `Configuration`, …) as an
   error — all false positives. Reuse the definitions the luau-lsp editor extension already
   cached:

   ```bash
   defs=$(ls "$HOME/Library/Application Support/Code/User/globalStorage/johnnymorganz.luau-lsp/globalTypes."*".d.luau" 2>/dev/null | head -1)
   names=$(echo "$files" | xargs -n1 basename | paste -sd'|' -)
   echo "$files" | xargs luau-lsp analyze --sourcemap sourcemap.json --base-luaurc .luaurc --no-strict-dm-types ${defs:+--definitions="$defs"} 2>&1 \
     | grep -E "($names)" || echo "no luau-lsp errors referencing your changed files"
   ```

   `analyze` walks the whole require graph, so it prints errors from `Packages/`, `Maid`,
   `Component`, and unrelated files — the `grep` keeps only lines that name a file you
   changed. If `$defs` is empty (extension not installed / different OS), say so — the
   luau-lsp run is unreliable without it; lean on selene + stylua and skip luau-lsp rather
   than chase ghosts.

4. **Interpret and act:**
   - **selene** and **stylua** are the hard gate. `stylua --check` fails → run
     `echo "$files" | xargs stylua` to auto-fix, then re-check. selene error on a line you
     touched → fix it.
   - **luau-lsp is advisory, not a clean bar.** This codebase is `nonstrict` with a generic
     Component system — an untouched file routinely reports dozens of structural TypeErrors.
     Do **not** try to zero them out. Only act on an error that references a line **you**
     changed and is plausibly real. To tell new from pre-existing, check whether the flagged
     construct appears in `git diff`. Pre-existing → mention, don't fix.
   - All clear (selene + stylua green, no new luau-lsp errors on your lines) → say so plainly.

## Notes

- Static analysis is the whole gate here. If a change has runtime behavior worth
  confirming, the Roblox Studio MCP (`mcp__Roblox_Studio__*`) can run Luau in a live
  session — use it when correctness can't be settled by reading the diff.
- Never edit generated/managed files to make a check pass: `Packages/`,
  `ServerPackages/`, `sourcemap.json`, `wally.lock`, `assets/*.rbxm`.
