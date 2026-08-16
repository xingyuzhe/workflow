# Module responsibility

`workflow-cli` owns local lifecycle state calculation, schema-driven artifact validation, semantic delta preparation, capability synchronization, archive movement, lifecycle mutation transactions, artifact integrity, legacy-residue diagnosis, and read-only local diagnostics.

# Structure and interfaces

- `.workflow/cli/workflow.ps1`: source entry point.
- `.workflow/cli/WorkflowRuntime.psm1`: source implementation.
- `.agents/skills/workflow/bin/`: generated published copy.
- Commands return human-readable output by default and structured JSON with `--json`.
- `kind: document` uses template-section and placeholder validation.
- `kind: task-list` adds checklist syntax and archive-completion validation.
- `kind: capability-deltas` validates capability pairs and publishes to schema `publishPath`.
- Delta preparation maintains a unique ordered requirement map and distinguishes equivalent replay from conflict.
- A change-local `.sync.json` receipt records the last published spec hash. It authorizes rename replay only while the accepted spec still matches the previously published result; it is lifecycle data, not global state.

# Transaction data model

- `.workflow/.mutation.lock`: exclusive writer token held open for the mutation lifetime.
- `.workflow/.transactions/<guid>/journal.json`: strict phase and target manifest.
- `.workflow/.transactions/<guid>/original/<index>`: byte-for-byte original files or directories.
- `.workflow/.transactions/<guid>/prepared/<index>`: prepared replacement files or directories.

Journal targets are repository-relative and declare operation, prior existence, original location, and prepared location. Runtime validation rejects rooted paths, traversal, duplicates, overlaps, unknown fields, invalid phases, reserved paths, unsafe characters, and reparse points.

# Commit and recovery

Sync prepares each complete capability directory and its receipt before target mutation. Archive additionally prepares the archive directory and active-change removal. The coordinator persists `prepared`, changes the phase to `committing`, applies targets, persists `committed`, and then removes transaction residue.

A caught exception during `committing` restores all targets. Before a later mutation plans new writes, recovery discards `prepared`, restores `committing`, and preserves target state while cleaning `committed`. Doctor reports lock or transaction residue without acquiring the lock or recovering it.

# Diagnosis boundaries

- Legacy path checks run during `doctor` after schema and accepted-spec validation.
- Metadata discovery is bounded to `.workflow/changes` and matches the exact `.openspec.yaml` leaf name.
- Cursor checks use the exact old namespace, fixed command filenames, and legacy content markers for the router.
- The old Codex skill is matched by its exact path.
- Errors identify repository-relative paths; current and private Cursor content is ignored, and Doctor remains read-only.

# Relationships

`schema-pack` declares artifact roles and publication paths. `deploy-kit` builds and validates the published CLI and consumes CLI Doctor results rather than reimplementing selected-schema, main-spec, transaction, or artifact-integrity validation. The deployment module and published runtime duplicate only the small legacy-residue vocabulary required for independent source and artifact operation. `workflow-runtime` routes agent intent to exact local commands and contracts.
