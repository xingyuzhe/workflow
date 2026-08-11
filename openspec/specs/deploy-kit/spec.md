# deploy-kit Specification

## Purpose

Deploy and validate the platform-neutral Workflow runtime for Cursor and Codex.

## Requirements

### Requirement: Generate client adapters from neutral source
Init SHALL copy the workflow-owned `.workflow/pack`, preserve project-owned `.workflow/mcp.json`, `.workflow/rules.json`, and `.workflow/rules/`, then generate only the selected client runtime assets. Client adapter files SHALL NOT be used as source input.

#### Scenario: Default project init
- **WHEN** init runs with `-Yes`
- **THEN** both clients SHALL receive deterministic adapters generated from `.workflow`

### Requirement: Client-scoped deployment

Init SHALL accept an explicit set of clients. It SHALL generate, clean, repair, and validate only the selected client adapters while continuing to install the neutral shared core.

#### Scenario: Codex-only deployment

- **WHEN** init runs with `-Clients codex`
- **THEN** Codex assets SHALL be generated and the `.cursor` tree SHALL remain byte-for-byte unchanged

### Requirement: Persistent installation scope

Deployment metadata SHALL record the installed client set. Repair and Doctor SHALL use that set when no explicit client set is provided.

#### Scenario: Repair Codex-only installation

- **WHEN** repair runs without a client argument after a Codex-only install
- **THEN** it SHALL repair Codex assets without adopting Cursor assets

### Requirement: Strict structured source
Init SHALL reject unknown fields, invalid types, unsafe paths, duplicate rules, and transport definitions missing required fields.

#### Scenario: Unknown MCP field
- **WHEN** a server contains an unsupported field
- **THEN** init SHALL fail naming that field

### Requirement: Preserve project-owned surroundings
Init SHALL update only indexed generated files and marked managed blocks. It SHALL preserve `AGENTS.md` and `.codex/config.toml` content outside managed blocks and SHALL NOT broadly delete unindexed rule files.

#### Scenario: Reinstall
- **WHEN** init runs twice
- **THEN** exactly one managed block SHALL remain and project-owned surrounding content SHALL be unchanged

### Requirement: Isolate and merge OpenSpec config
Init SHALL overwrite `config.workflow.yaml`, preserve `config.project.yaml`, and generate `config.yaml`. A missing project config MAY be initialized or migrated from an existing bare `config.yaml`. Business specs SHALL remain untouched.

#### Scenario: Stale merged config
- **WHEN** project config changes after install
- **THEN** default Doctor SHALL report drift without modifying `config.yaml`

### Requirement: Read-only Doctor and explicit repair
Doctor SHALL be read-only by default and SHALL compare generated rules, commands, MCP config, managed blocks, skill references, metadata, OpenSpec merged config, and spec/design pairs. `doctor -Fix` SHALL explicitly regenerate workflow-owned outputs and rerun strict validation.

#### Scenario: Generated file drift
- **WHEN** an adapter differs from canonical source
- **THEN** Doctor SHALL fail and leave the file unchanged

#### Scenario: Explicit fix
- **WHEN** Doctor runs with `-Fix`
- **THEN** it SHALL repair owned output and pass only after a subsequent strict check succeeds

### Requirement: Single metadata authority
Deploy SHALL write version and manifest only under `.workflow`. Runtime state SHALL exist only at `.workflow/state.json`. Superseded client metadata, state, and `.cursor/workflow/pack` SHALL be removed and cause Doctor failure if reintroduced.

#### Scenario: Successful init
- **WHEN** init completes
- **THEN** `.workflow/version.json` and `.workflow/manifest.json` SHALL match the installed version and no client metadata copy SHALL remain

### Requirement: Local schema validation
Doctor SHALL validate the project-local workflow schema and spec/design pairs. When OpenSpec CLI is available it SHALL additionally verify project-local schema resolution; it SHALL NOT use a machine/version-specific executable fallback.

#### Scenario: CLI unavailable
- **WHEN** the OpenSpec executable is not discoverable
- **THEN** Doctor SHALL still validate local schema files without assuming an NVM version path
