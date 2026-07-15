# Apply — implement OpenSpec change tasks

Read `.cursor/workflow/pack/gates/tdd.md`, `verify.md`, and `debug.md` before writing code. Follow them as MUST rules.

## Steps

1. Identify change name (argument, context, or `openspec list`). Announce: `Using change: <name>`.
2. Confirm branch is `change/<name>` (see `branch.md`). Do not implement on `main`/`master`.
3. ```text
   openspec status --change "<name>"
   openspec instructions apply --change "<name>" --json
   ```
4. Read every path under `contextFiles` from apply instructions.
5. Show progress (N/M tasks). Work pending tasks in order.
6. For each task:
   - Code logic → TDD gate (RED→GREEN→REFACTOR). Docs/config/rename → TDD not required; if unsure, ask user.
   - On failure → debug gate (no random fixes; pause after 3 failed attempts).
   - Before `- [ ]` → `- [x]`: verify gate (runtime evidence required).
7. After every 3 tasks, run the project test suite (or record why none exists) and report.
8. On all done: suggest `/opsx:verify` → `finish.md` → `/opsx:archive`. Wait for user decisions.

If `state.json` exists under `.cursor/workflow/`, read it and reconcile with `openspec status` (CLI wins). Missing state must not block apply. Update state when useful (`phase: apply`).

## Done when

- All requested tasks are `[x]` with verification evidence, or user pauses with remaining list.
