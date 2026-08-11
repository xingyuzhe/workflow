# workflow-runtime delta design

## Responsibility

Route explicit lifecycle intent to compact, platform-neutral contracts.

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

- Prompts define lifecycle delivery contracts.
- `acceptance.md` defines shared evidence requirements.
- Project rules may add targeted methodology constraints.

## Relationships

- `schema-pack` owns artifact syntax and dependencies.
- `quality-gates` owns completion evidence semantics.
