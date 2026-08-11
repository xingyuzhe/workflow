# workflow-runtime Design

## Responsibility

Route explicit lifecycle intent to compact, platform-neutral delivery contracts.

## Structure

```text
.workflow/pack/
  prompts/*.md
  gates/acceptance.md
        |
        +-- Cursor commands/router
        +-- Codex skill references/AGENTS routing
```

## Interfaces

- Prompts define lifecycle inputs, outputs, acceptance, stop conditions, and authority.
- `acceptance.md` defines shared completion evidence.
- Project rules and active artifacts may add targeted method constraints.
- Project-specific rules, skills, and guidance stay in their owning downstream repository and are not shared deployment input.
- Optional local state lives only at `.workflow/state.json`; OpenSpec status remains authoritative.

## Relationships

- `schema-pack` owns artifact syntax and dependencies.
- `quality-gates` owns completion evidence semantics.
