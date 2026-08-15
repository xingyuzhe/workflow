# Module responsibility

`workflow-cli` owns strict artifact-role interpretation and semantic delta preflight.

# Structure and interfaces

- `kind: document` uses template-section and placeholder validation.
- `kind: task-list` adds checklist syntax and archive-completion validation.
- `kind: capability-deltas` validates capability pairs and publishes to schema `publishPath`.
- A change-local `.sync.json` receipt records the last published spec hash. It authorizes rename replay only while the accepted spec still matches the previously published result; it is lifecycle data, not global state.
- Delta preparation maintains a unique ordered requirement map and distinguishes equivalent replay from conflict.

# Relationships

`schema-pack` declares artifact roles. `deploy-kit` consumes CLI Doctor results rather than reimplementing selected-schema and main-spec validation.
