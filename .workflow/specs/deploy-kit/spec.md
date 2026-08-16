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
Publish SHALL generate and copy exactly one Codex runtime at `.agents/skills/workflow`, including its local CLI, references, metadata, and manifest. It SHALL install project-owned `.workflow` configuration and schema data without publishing source-only pack or CLI directories as a second runtime. It SHALL migrate supported legacy project data, including a root design, before rejecting any remaining legacy namespace.

#### Scenario: Publish workflow artifact
- **WHEN** publish runs for a downstream repository containing supported legacy workflow data
- **THEN** `.agents/skills/workflow` SHALL be complete, project data SHALL be under `.workflow`, superseded workflow-owned runtime paths SHALL be absent, and no external package SHALL be required

#### Scenario: Legacy root design exists
- **WHEN** `openspec/design.md` exists and `.workflow/design.md` does not
- **THEN** publication SHALL preserve its content at `.workflow/design.md` and remove the obsolete root

#### Scenario: Root designs conflict
- **WHEN** both legacy and current root designs exist with different normalized content
- **THEN** publication MUST fail in preflight without changing the target

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
Publish SHALL update only its named artifact namespace and marked managed blocks. It SHALL preserve `AGENTS.md` and `.codex/config.toml` content outside managed blocks and SHALL NOT broadly delete project-owned rules or unrelated skills. Managed AGENTS guidance SHALL include the project-rules section only when at least one concrete project rule is configured.

#### Scenario: Reinstall
- **WHEN** publish runs twice
- **THEN** exactly one managed block SHALL remain and project-owned surrounding content SHALL be unchanged

#### Scenario: Project has no rules
- **WHEN** publication generates AGENTS guidance without a project rule catalog
- **THEN** the managed block SHALL omit the project-rules heading and contain no empty rule section

### Requirement: Isolate and merge workflow config
Publish SHALL overwrite `config.workflow.json`, preserve `config.project.json`, and generate `config.json`. A missing project config MAY be initialized as an empty strict JSON object. Former YAML configuration MUST NOT be read or migrated. Business specs SHALL remain untouched.

#### Scenario: Stale merged config
- **WHEN** project config changes after install
- **THEN** default Doctor SHALL report drift without modifying `config.json`

### Requirement: Read-only Doctor and explicit repair
Artifact Doctor SHALL be read-only and SHALL compare the complete published skill against the source artifact, validate metadata, reject source-only runtime directories downstream, reject supported legacy workflow residue, and invoke the published local Doctor to check selected schema, accepted specs, spec/design pairs, complete artifact integrity, and the same legacy residue. Text comparison MUST treat LF and CRLF as equivalent while detecting every other content difference. Repair requires an explicit build, deploy, or init operation outside Doctor.

#### Scenario: Generated file drift
- **WHEN** an adapter differs from canonical source
- **THEN** Doctor SHALL fail and leave the file unchanged

#### Scenario: Git converts artifact line endings
- **WHEN** source and published text artifacts differ only by line endings
- **THEN** Artifact Doctor MUST accept their content as equivalent

#### Scenario: Artifact text actually changes
- **WHEN** a published artifact differs by content other than line endings
- **THEN** Artifact Doctor MUST report drift and leave the file unchanged

#### Scenario: Legacy migration metadata remains
- **WHEN** `.workflow/changes` contains `.openspec.yaml`
- **THEN** Artifact Doctor MUST report the exact legacy metadata path and remain read-only

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
The breaking migration SHALL remove exact workflow-owned superseded skills, command adapters, external CLI probes, old live configuration/schema paths, provenance-verified legacy deployment scripts, legacy change metadata, and the exact former Cursor workflow namespace after migrating project change, spec, and root-design data. It MUST preserve similarly named project content, current Cursor adapters, and unrelated Cursor content.

#### Scenario: Upgrade an existing repository
- **WHEN** standard Codex publication completes against a supported legacy installation
- **THEN** project data MUST exist only in the new workflow namespace and superseded workflow-owned Codex and Cursor runtime paths MUST be absent

#### Scenario: Remove legacy Cursor adapters selectively
- **WHEN** the target contains `.cursor/workflow`, fixed `opsx-<operation>.md` commands, an old-marker router, a private command, and current `/workflow:*` adapters
- **THEN** publication SHALL remove only the legacy namespace, opsx commands, and old-marker router

### Requirement: Cross-runtime deterministic generation
Workflow-owned generated files SHALL be byte-identical when produced by supported Windows PowerShell and PowerShell 7 runtimes from identical source input.

#### Scenario: Build with both PowerShell runtimes
- **WHEN** build or self-install runs once with each supported runtime
- **THEN** no tracked generated file MUST change between runs

### Requirement: Failure-safe target mutation
Full installation and artifact-only publication SHALL validate all known source, configuration, schema, ownership, migration, root-design collision, and cleanup constraints before changing a target. If a caught mutation failure occurs after writes begin, the operation MUST restore every workflow-owned target path it changed, including bounded legacy Cursor candidates.

#### Scenario: Invalid target configuration
- **WHEN** installation receives an invalid project MCP, rule, configuration, selected schema definition, or conflicting root design
- **THEN** it MUST fail before deleting or writing any target content

#### Scenario: Mutation fails after preflight
- **WHEN** a filesystem mutation throws after target changes begin
- **THEN** the operation MUST restore the snapshotted workflow-owned target state before reporting failure

#### Scenario: Failure follows Cursor cleanup
- **WHEN** publication fails after removing a legacy Cursor candidate
- **THEN** that candidate and every earlier project-data mutation MUST be restored byte-for-byte

### Requirement: Explicit workflow ownership
Cleanup SHALL delete only exact legacy namespaces, exact current workflow namespaces, fixed legacy command paths, files recorded by a workflow-managed index, or a router whose content contains required legacy routing markers. It MUST NOT infer ownership solely from a generic `workflow-` name prefix, a loose source-code marker, or the existence of unrelated Cursor content.

#### Scenario: Project has a workflow-prefixed private skill
- **WHEN** the target contains `.cursor/skills/workflow-private`
- **THEN** install MUST preserve it byte-for-byte

#### Scenario: Downstream has project-owned neutral inputs
- **WHEN** artifact publication finds project `.workflow/rules.json`, `.workflow/rules/`, or `.workflow/mcp.json`
- **THEN** it MUST preserve and compile those inputs without replacing them with source-repository defaults

#### Scenario: Router is current or private
- **WHEN** `.cursor/rules/workflow-router.mdc` contains no former OpenSpec or opsx routing marker
- **THEN** standard Codex publication MUST preserve it byte-for-byte

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

### Requirement: Deterministic migration report
Standard Codex publication SHALL produce a deterministic migration report with sorted repository-relative `migrated`, `removed`, `preserved`, and `blocked` path arrays. The report SHALL be evidence only and MUST NOT become lifecycle state. `deploy.ps1` SHALL expose the report as opt-in JSON together with artifact version and Doctor validity.

#### Scenario: Publication reports its migration
- **WHEN** a legacy downstream repository is published successfully with JSON output
- **THEN** every planned legacy action is classified and Doctor validity is included without absolute-path or runtime-order drift in the action arrays

#### Scenario: Publication is repeated
- **WHEN** publication runs again against the converged repository
- **THEN** the filesystem remains unchanged and no completed legacy action is reported as newly migrated or removed
