# deploy-kit Specification

## Purpose

Build, publish, and validate the platform-neutral Workflow runtime for Cursor and Codex.

## Requirements

### Requirement: Generate client adapters from neutral source
Build SHALL generate client artifacts from the workflow-owned `.workflow` source. The workflow repository SHALL retain both the editable source and generated artifact so it exercises the same Codex runtime that it publishes. Client adapter files SHALL NOT be used as source input.

#### Scenario: Build the workflow repository
- **WHEN** build runs after a neutral contract changes
- **THEN** the repository's Codex artifact SHALL be regenerated deterministically

### Requirement: Artifact-only downstream publication
Publish SHALL generate and copy exactly one Codex runtime at `.agents/skills/workflow`, including its local CLI, references, metadata, and manifest. It SHALL install project-owned `.workflow` configuration and schema data without publishing source-only pack or CLI directories as a second runtime.

#### Scenario: Publish workflow artifact
- **WHEN** publish runs for a downstream repository
- **THEN** `.agents/skills/workflow` SHALL be complete, old lifecycle namespaces SHALL be absent, and no external package SHALL be required

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

### Requirement: Isolate and merge workflow config
Publish SHALL overwrite `config.workflow.yaml`, preserve `config.project.yaml`, and generate `config.yaml`. A missing project config MAY be initialized or migrated from existing lifecycle configuration. Business specs SHALL remain untouched.

#### Scenario: Stale merged config
- **WHEN** project config changes after install
- **THEN** default Doctor SHALL report drift without modifying `config.yaml`

### Requirement: Read-only Doctor and explicit repair
Artifact Doctor SHALL be read-only and SHALL compare the complete published skill against the source artifact, validate metadata, reject source-only runtime directories downstream, and check local schema and spec/design pairs. Text comparison MUST treat LF and CRLF as equivalent while detecting every other content difference.

#### Scenario: Generated file drift
- **WHEN** an adapter differs from canonical source
- **THEN** Doctor SHALL fail and leave the file unchanged

#### Scenario: Git converts artifact line endings
- **WHEN** source and published text artifacts differ only by line endings
- **THEN** Artifact Doctor MUST accept their content as equivalent

#### Scenario: Artifact text actually changes
- **WHEN** a published artifact differs by content other than line endings
- **THEN** Artifact Doctor MUST report drift and leave the file unchanged

### Requirement: Single metadata authority
The workflow source SHALL keep build metadata under `.workflow`. The generated Codex runtime SHALL keep published version and manifest inside `.agents/skills/workflow`. Downstream `.workflow` SHALL contain only project data, configuration, and schema rather than a second runtime.

#### Scenario: Successful publication
- **WHEN** publication completes
- **THEN** artifact metadata SHALL match the source artifact and downstream source-only pack and CLI directories SHALL be absent

### Requirement: Local schema validation
Doctor SHALL validate the project-local workflow schema and spec/design pairs using repository files only.

#### Scenario: External commands unavailable
- **WHEN** no external lifecycle command is discoverable
- **THEN** Doctor SHALL still complete local schema validation

### Requirement: Remove superseded namespaces
The breaking migration SHALL remove workflow-owned superseded skills, command adapters, external CLI probes, and old live configuration/schema paths after migrating project change and spec data.

#### Scenario: Upgrade an existing repository
- **WHEN** version 5.0.0 publication completes
- **THEN** project data MUST exist only in the new workflow namespace and superseded workflow-owned runtime paths MUST be absent
