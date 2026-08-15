# Branch contract

## Required state

- Workflow change work is isolated from `main`/`master` on a change branch.
- Default branch name: `change/<name>`.
- Use a worktree only when parallel isolation or environment constraints require one.

## Acceptance

- The active workspace and branch are identified before implementation starts.

## Authority

- Do not discard, overwrite, or rewrite unrelated branch state without explicit authorization.
