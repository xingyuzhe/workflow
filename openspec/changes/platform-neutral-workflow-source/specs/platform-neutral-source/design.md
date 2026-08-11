## Context

Client-native configuration formats differ and evolve independently. Treating either client's files as canonical couples all other adapters to that client.

## Decisions

- `.workflow/pack/{prompts,gates}` contains neutral Markdown.
- `.workflow/mcp.json` contains strict transport definitions plus explicit client extension objects.
- `.workflow/rules.json` contains routing metadata and references Markdown bodies under `.workflow/rules/`.
- Adapter files are replaced only within workflow-owned files or managed blocks.

## Invariants

- Every generated file is reproducible from `.workflow` plus project-owned managed-block surroundings.
- Unknown structured fields fail validation.
- No adapter is used to regenerate another adapter.
