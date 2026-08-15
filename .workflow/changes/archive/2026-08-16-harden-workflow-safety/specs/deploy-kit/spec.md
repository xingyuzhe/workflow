## ADDED Requirements

### Requirement: Failure-safe target mutation
Full installation and artifact-only publication SHALL validate all known source, configuration, schema, ownership, and migration constraints before changing a target. If a caught mutation failure occurs after writes begin, the operation MUST restore every workflow-owned target path it changed.

#### Scenario: Invalid target configuration
- **WHEN** installation receives an invalid project MCP, rule, configuration, or selected schema definition
- **THEN** it MUST fail before deleting or writing any target content

#### Scenario: Mutation fails after preflight
- **WHEN** a filesystem mutation throws after target changes begin
- **THEN** the operation MUST restore the snapshotted workflow-owned target state before reporting failure

### Requirement: Explicit workflow ownership
Cleanup SHALL delete only exact legacy namespaces, exact current workflow namespaces, or files recorded by a workflow-managed index. It MUST NOT infer ownership solely from a generic `workflow-` name prefix or a loose source-code marker.

#### Scenario: Project has a workflow-prefixed private skill
- **WHEN** the target contains `.cursor/skills/workflow-private`
- **THEN** install MUST preserve it byte-for-byte

#### Scenario: Downstream has project-owned neutral inputs
- **WHEN** artifact publication finds project `.workflow/rules.json`, `.workflow/rules/`, or `.workflow/mcp.json`
- **THEN** it MUST preserve and compile those inputs without replacing them with source-repository defaults

### Requirement: Consistent complete Doctor
Source Doctor and Artifact Doctor SHALL include the published local Doctor checks and SHALL additionally verify their own source-equivalence obligations. Every Doctor MUST reject extra unmanifested runtime files and a missing or invalid schema selected by project configuration.

#### Scenario: Generated CLI drifts
- **WHEN** the generated CLI differs from its manifest or source CLI
- **THEN** source Doctor MUST report unhealthy

#### Scenario: Artifact contains an extra file
- **WHEN** a published skill contains a file absent from its manifest
- **THEN** Artifact Doctor and local Doctor MUST both report unhealthy

### Requirement: Explicit deployment modes
Documentation and script interfaces SHALL distinguish full Cursor+Codex installation from Codex artifact-only publication, including the exact source-only directories and deployment scripts present or absent in each mode.

#### Scenario: First-time downstream deployment
- **WHEN** a user wants the standard Codex downstream runtime
- **THEN** documentation MUST direct them to artifact-only publication rather than full source-layout installation

### Requirement: Strict self-contained configuration
Workflow, project, and generated configuration SHALL use strict JSON parsed with built-in PowerShell facilities. Unknown fields, invalid schema names, non-object rules, or non-string rule entries MUST fail explicitly.

#### Scenario: Configuration contains an unsupported shape
- **WHEN** configuration merge reads an unknown field or invalid rule value
- **THEN** it MUST fail without silently dropping configuration

## MODIFIED Requirements

### Requirement: Isolate and merge workflow config
Publish SHALL overwrite `config.workflow.json`, preserve `config.project.json`, and generate `config.json`. A missing project config MAY be initialized as an empty strict JSON object. Former YAML configuration MUST NOT be read or migrated. Business specs SHALL remain untouched.

#### Scenario: Stale merged config
- **WHEN** project config changes after install
- **THEN** default Doctor SHALL report drift without modifying `config.json`

### Requirement: Read-only Doctor and explicit repair
Artifact Doctor SHALL be read-only and SHALL compare the complete published skill against the source artifact, validate metadata, reject source-only runtime directories downstream, and invoke the published local Doctor to check selected schema, accepted specs, spec/design pairs, and complete artifact integrity. Text comparison MUST treat LF and CRLF as equivalent while detecting every other content difference. Repair requires an explicit build, deploy, or init operation outside Doctor.

#### Scenario: Generated file drift
- **WHEN** an adapter differs from canonical source
- **THEN** Doctor SHALL fail and leave the file unchanged

#### Scenario: Git converts artifact line endings
- **WHEN** source and published text artifacts differ only by line endings
- **THEN** Artifact Doctor MUST accept their content as equivalent

#### Scenario: Artifact text actually changes
- **WHEN** a published artifact differs by content other than line endings
- **THEN** Artifact Doctor MUST report drift and leave the file unchanged

### Requirement: Remove superseded namespaces
The breaking migration SHALL remove exact workflow-owned superseded skills, command adapters, external CLI probes, old live configuration/schema paths, and provenance-verified legacy deployment scripts after migrating project change and spec data. It MUST preserve similarly named project content.

#### Scenario: Upgrade an existing repository
- **WHEN** version 6.0.0 publication completes
- **THEN** project data MUST exist only in the new workflow namespace and superseded workflow-owned runtime paths MUST be absent
