## ADDED Requirements

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

### Requirement: Overwrite openspec config template
Init SHALL overwrite `openspec/config.yaml` with the workflow-shipped template (schema default `workflow-spec` and SSOT/pair rules). Init SHALL NOT merge with a pre-existing config. Init SHALL NOT delete business `openspec/specs/**` content.

#### Scenario: Existing custom config
- **WHEN** the target already has `openspec/config.yaml`
- **THEN** init MUST replace it entirely with the workflow template

### Requirement: Doctor fails on legacy residue
Doctor SHALL check pack presence, router presence, **project-local `workflow-spec` schema resolution** (via `openspec schema which` when the CLI is available), version/manifest consistency, and absence of purged workflow legacy skill trees. Residual v1 workflow skills under the purge namespaces SHALL cause doctor to **fail** (non-zero). Incomplete pack SHALL fail. If the OpenSpec CLI cannot be found, doctor SHALL fail with an actionable message (schema resolution unverifiable).

#### Scenario: Missing apply prompt
- **WHEN** doctor runs and `.cursor/workflow/pack/prompts/apply.md` is missing
- **THEN** doctor MUST fail naming the missing path

#### Scenario: Leftover superpowers skills
- **WHEN** doctor finds `.cursor/skills/superpowers-v6.1.1` (or other purge-namespace residue)
- **THEN** doctor MUST fail

#### Scenario: Schema resolves from project
- **WHEN** doctor runs and the OpenSpec CLI is available
- **THEN** `openspec schema which workflow-spec` MUST resolve to the project's `openspec/schemas/workflow-spec` (source project, not package)
### Requirement: Version and manifest metadata
Deploy SHALL write `.cursor/workflow/version.json` and `.cursor/workflow/manifest.json`. Doctor SHALL use them when validating. Init SHALL run doctor after deploy and MUST exit non-zero if doctor fails.

#### Scenario: After successful init
- **WHEN** init completes successfully
- **THEN** version and manifest MUST exist and match installed contents, and doctor MUST have passed
