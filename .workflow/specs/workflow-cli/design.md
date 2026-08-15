# Module responsibility

`workflow-cli` owns local lifecycle state calculation, artifact instructions, validation, capability synchronization, and archive movement.

# Structure and interfaces

- `.workflow/cli/workflow.ps1`: source entry point.
- `.workflow/cli/WorkflowRuntime.psm1`: source implementation.
- `.agents/skills/workflow/bin/`: generated published copy.
- Commands return human-readable output by default and structured JSON with `--json`.

# State

The filesystem is authoritative. Active changes are directories under `.workflow/changes` excluding `archive`; main capabilities are pairs under `.workflow/specs`.

# Relationships

`schema-pack` supplies local schema metadata and templates. `deploy-kit` builds and validates the published CLI. `workflow-runtime` routes agent intent to exact local commands and contracts.
