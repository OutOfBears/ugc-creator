# Contributing

## Branch and commit conventions

- Branch names: `feature/*`, `task/*`, `support/*`, `hotfix/*`, `release/v*`
- Commit messages: Conventional Commits (`type(scope): summary`)

## Pull requests

Use the PR template and keep PRs focused. Each PR should include:

- clear problem and solution summary
- risk and rollback notes
- validation steps and results
- screenshots/video for UI or gameplay changes

## Local verification

Run the project quality gate before requesting review:

```bash
rojo sourcemap default.project.json -o sourcemap.json
selene <changed-files>
stylua --check <changed-files>
```

`luau-lsp analyze` is advisory in this repo.

## AI and Copilot context

- `CLAUDE.md` is the canonical architecture/conventions guide.
- `.github/copilot-instructions.md` provides Copilot-specific guidance.
- Keep changes surgical and avoid touching generated/managed files unless intentional.

