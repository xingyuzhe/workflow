## Context

Cursor and Codex need different discovery paths, but the workflow semantics are identical.

## Decisions

- Keep neutral prompt text free of client-owned paths where possible.
- Generate Cursor commands that load `.workflow/pack` directly.
- Generate Codex skill references from the same pack for progressive disclosure.
- Refer to `.workflow/state.json` from both clients.
