# deploy-kit Specification

## Purpose
TBD - created by archiving change workflow-v2. Update Purpose after archive.
## Requirements
### Requirement: Init deploys isomorphic pack layout
The deploy kit SHALL provide PowerShell-first entrypoints (`init.ps1` and doctor script). Init SHALL install: v2 router, `/opsx:*` commands, `.cursor/workflow/pack/` (same paths as source), `openspec/schemas/workflow-spec/`, version/manifest metadata. Init SHALL NOT install Superpowers or OpenSpec skill trees as runtime.

#### Scenario: Fresh project init
- **WHEN** a user runs init with `-Yes` on a Cursor project
- **THEN** the project MUST gain pack + router + commands + `workflow-spec` schema and MUST NOT require any `superpowers*` / `openspec-v*` skill tree

### Requirement: Destructive purge of workflow legacy (no coexistence flag)
Init SHALL unconditionally remove workflow-namespace skill trees under `.cursor/skills` matching `superpowers*`, `openspec*`, `grilling*`, and `workflow*` (including versioned directories). Init SHALL remove workflow-owned entry files (including `opsx-*` commands and known obsolete bootstrap/router files matching workflow legacy names) before reinstalling v2 entries. Init SHALL NOT provide a `--keep-v1-skills` (or equivalent) coexistence flag.

#### Scenario: Upgrade from v1
- **WHEN** init runs on a project that still has v1 workflow skills
- **THEN** those skill trees MUST be deleted as part of deploy with no opt-out flag

#### Scenario: Stale opsx commands
- **WHEN** init runs and old `opsx-*` command files exist
- **THEN** those files MUST be removed and replaced by the current v2 command set

### Requirement: Isolate and merge openspec config
Init SHALL overwrite `openspec/config.workflow.yaml` with the workflow-shipped template (schema default `workflow-spec` and SSOT/pair rules). Init SHALL NEVER overwrite `openspec/config.project.yaml`. Init SHALL regenerate `openspec/config.yaml` by merging workflow + project configs. Rules SHALL merge per artifact key (workflow items first, then project, dedupe preserving order). Scalar fields such as `schema` SHALL use workflow as the base; an explicit project scalar SHALL override. When `config.project.yaml` is absent and a legacy `config.yaml` exists, init SHALL rename that file to `config.project.yaml` before writing the workflow template and regenerating the merge. When no project file exists after migration, init SHALL write a minimal empty project shell. Init SHALL NOT delete business `openspec/specs/**` content. Doctor SHALL auto-sync (merge) `openspec/config.yaml` from the workflow + project sources before validating, and SHALL be a no-op write when the merge output is unchanged.

#### Scenario: Existing custom config migrates once
- **WHEN** the target has `openspec/config.yaml` but no `config.project.yaml`
- **THEN** init MUST rename the existing file to `config.project.yaml`, write `config.workflow.yaml`, and regenerate merged `config.yaml` that still contains the previous project rules

#### Scenario: Project config never overwritten
- **WHEN** `openspec/config.project.yaml` already exists and init runs twice
- **THEN** the project file content MUST remain unchanged across both runs while `config.workflow.yaml` and merged `config.yaml` MAY be refreshed

#### Scenario: Doctor syncs stale merge after project edit
- **WHEN** `config.project.yaml` gains a new rule and `config.yaml` is stale
- **THEN** doctor MUST regenerate `config.yaml` to include that rule before other checks

#### Scenario: Business specs preserved
- **WHEN** init runs on a project with existing `openspec/specs/**`
- **THEN** those business specs MUST remain
### Requirement: Doctor fails on legacy residue
Doctor SHALL check pack presence, router presence, **project-local `workflow-spec` schema resolution** (via `openspec schema which` when the CLI is available), version/manifest consistency, absence of purged workflow legacy skill trees, and **spec/design pairing**. For every capability directory under `openspec/specs/` and under non-archive `openspec/changes/*/specs/`, if either `spec.md` or `design.md` exists, both MUST exist; otherwise doctor SHALL fail. Residual v1 workflow skills under the purge namespaces SHALL cause doctor to **fail** (non-zero). Incomplete pack SHALL fail. If the OpenSpec CLI cannot be found, doctor SHALL fail with an actionable message (schema resolution unverifiable).

#### Scenario: Missing apply prompt
- **WHEN** doctor runs and `.cursor/workflow/pack/prompts/apply.md` is missing
- **THEN** doctor MUST fail naming the missing path

#### Scenario: Leftover superpowers skills
- **WHEN** doctor finds `.cursor/skills/superpowers-v6.1.1` (or other purge-namespace residue)
- **THEN** doctor MUST fail

#### Scenario: Schema resolves from project
- **WHEN** doctor runs and the OpenSpec CLI is available
- **THEN** `openspec schema which workflow-spec` MUST resolve to the project's `openspec/schemas/workflow-spec` (source project, not package)

#### Scenario: Missing companion design
- **WHEN** `openspec/specs/foo/spec.md` exists and `openspec/specs/foo/design.md` does not
- **THEN** doctor MUST fail with an error identifying the incomplete pair

### Requirement: Version and manifest metadata
Deploy SHALL write `.cursor/workflow/version.json` and `.cursor/workflow/manifest.json`. Doctor SHALL use them when validating. Init SHALL run doctor after deploy and MUST exit non-zero if doctor fails.

#### Scenario: After successful init
- **WHEN** init completes successfully
- **THEN** version and manifest MUST exist and match installed contents, and doctor MUST have passed

