## MODIFIED Requirements

### Requirement: Artifact-only downstream publication
Publish SHALL generate and copy exactly one Codex runtime at `.agents/skills/workflow`, including its local CLI, references, metadata, and manifest. It SHALL install project-owned `.workflow` configuration and schema data without publishing source-only pack or CLI directories as a second runtime.

#### Scenario: Publish workflow artifact
- **WHEN** publish runs for a downstream repository
- **THEN** `.agents/skills/workflow` SHALL be complete, old lifecycle namespaces SHALL be absent, and no external package SHALL be required

### Requirement: Remove superseded namespaces
The breaking migration SHALL remove workflow-owned superseded skills, command adapters, external CLI probes, and old live configuration/schema paths after migrating project change and spec data.

#### Scenario: Upgrade an existing repository
- **WHEN** version 5.0.0 publication completes
- **THEN** project data MUST exist only in the new workflow namespace and superseded workflow-owned runtime paths MUST be absent

## ADDED Requirements

### Requirement: Cross-runtime deterministic generation
Workflow-owned generated files SHALL be byte-identical when produced by supported Windows PowerShell and PowerShell 7 runtimes from identical source input.

#### Scenario: Build with both PowerShell runtimes
- **WHEN** build or self-install runs once with each supported runtime
- **THEN** no tracked generated file MUST change between runs
