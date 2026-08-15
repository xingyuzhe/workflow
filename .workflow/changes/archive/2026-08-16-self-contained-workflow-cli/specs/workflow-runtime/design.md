# Module responsibility

`workflow-runtime` owns lifecycle routing, operation contracts, state authority, and authorization boundaries.

# Structure and interfaces

- Codex entry: `.agents/skills/workflow/SKILL.md` and `$workflow`.
- Cursor entry: `/workflow:<operation>`.
- Runtime status: exact invocation of the published local CLI.
- Neutral contracts: source `.workflow/pack`, generated into client-native adapters.

# State

Repository artifacts are authoritative. No `.workflow/state.json` cache is required.

# Relationships

`workflow-cli` evaluates lifecycle state. `schema-pack` owns artifact syntax. `deploy-kit` publishes adapters and CLI files.
