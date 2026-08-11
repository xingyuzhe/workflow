# deploy-kit Specification

## Purpose

Deploy and validate the platform-neutral Workflow runtime for Cursor and Codex.

## Requirements

### Requirement: Generate client adapters from neutral source
Build SHALL generate client artifacts from the workflow-owned `.workflow` source. The workflow repository SHALL retain both the editable neutral source and generated artifacts so it exercises the same Codex artifact that it publishes. Client adapter files SHALL NOT be used as source input.

#### Scenario: Build the workflow repository
- **WHEN** build runs after a neutral contract changes
- **THEN** the repository's Codex artifact SHALL be regenerated deterministically from `.workflow`

### Requirement: Artifact-only downstream publication

Publish SHALL copy the generated Codex artifact and required standard-path OpenSpec integration outputs. It SHALL NOT copy `.workflow` or the workflow deployment engine downstream.

#### Scenario: Publish Codex artifact

- **WHEN** publish runs for a downstream repository
- **THEN** `.agents/skills/openspec-workflow` SHALL match the source artifact and `.workflow` SHALL be absent

### Requirement: Preserve project-owned agents content

Publish SHALL modify only its managed skill namespace and bounded integration outputs. It SHALL preserve project-owned rules and unrelated skills.

#### Scenario: Project has private agents assets

- **WHEN** publication runs
- **THEN** private `.agents/rules` and unrelated `.agents/skills` SHALL remain unchanged

### Requirement: Strict structured source
Build SHALL reject unknown fields, invalid types, unsafe paths, duplicate rules, and transport definitions missing required fields.

#### Scenario: Unknown MCP field
- **WHEN** a server contains an unsupported field
- **THEN** init SHALL fail naming that field

### Requirement: Preserve project-owned surroundings
Publish SHALL update only its named artifact namespace and marked managed blocks. It SHALL preserve `AGENTS.md` and `.codex/config.toml` content outside managed blocks and SHALL NOT broadly delete project-owned rules or unrelated skills.

#### Scenario: Reinstall
- **WHEN** publish runs twice
- **THEN** exactly one managed block SHALL remain and project-owned surrounding content SHALL be unchanged

### Requirement: Isolate and merge OpenSpec config
Publish SHALL overwrite `config.workflow.yaml`, preserve `config.project.yaml`, and generate `config.yaml`. A missing project config MAY be initialized or migrated from an existing bare `config.yaml`. Business specs SHALL remain untouched.

#### Scenario: Stale merged config
- **WHEN** project config changes after install
- **THEN** default Doctor SHALL report drift without modifying `config.yaml`

### Requirement: Read-only Doctor and explicit repair
Artifact Doctor SHALL be read-only and SHALL compare the complete published skill against the source artifact, validate artifact metadata, require downstream neutral source to be absent, and check local OpenSpec schema and spec/design pairs.

#### Scenario: Generated file drift
- **WHEN** an adapter differs from canonical source
- **THEN** Doctor SHALL fail and leave the file unchanged

### Requirement: Single metadata authority
The workflow source SHALL keep source metadata under `.workflow`. The generated Codex artifact SHALL keep published version and manifest inside `.agents/skills/openspec-workflow`. A downstream repository SHALL contain only artifact metadata and SHALL NOT contain `.workflow` metadata or source.

#### Scenario: Successful publication
- **WHEN** publication completes
- **THEN** artifact metadata SHALL match the source artifact and no downstream `.workflow` directory SHALL remain

### Requirement: Local schema validation
Doctor SHALL validate the project-local workflow schema and spec/design pairs. When OpenSpec CLI is available it SHALL additionally verify project-local schema resolution; it SHALL NOT use a machine/version-specific executable fallback.

#### Scenario: CLI unavailable
- **WHEN** the OpenSpec executable is not discoverable
- **THEN** Doctor SHALL still validate local schema files without assuming an NVM version path
