# workflow-cli Specification

## Purpose

Define the accepted workflow-cli behavior.

### Requirement: Repository-owned local CLI
The workflow SHALL publish a repository-owned CLI that runs from an exact local path using PowerShell and built-in .NET only. It MUST NOT discover, install, download, or invoke an external lifecycle CLI or package manager.

#### Scenario: External tools are absent
- **WHEN** external lifecycle tools and package runtimes are unavailable
- **THEN** every supported workflow CLI command MUST remain operational

#### Scenario: Local CLI is missing
- **WHEN** the published local CLI path does not exist
- **THEN** the workflow MUST report an invalid installation and MUST NOT attempt network installation

### Requirement: Local lifecycle commands
The CLI SHALL provide `new`, `status`, `instructions`, `validate`, `sync`, `archive`, and `doctor` commands with deterministic JSON output where requested.

#### Scenario: Determine apply readiness
- **WHEN** status evaluates a change containing all required artifacts and complete capability pairs
- **THEN** it MUST report the change as apply-ready without consulting external state

#### Scenario: Archive completed work
- **WHEN** archive receives a validated change with completed tasks
- **THEN** it MUST synchronize accepted deltas and move the change into the local archive

### Requirement: Schema-driven artifact readiness
The CLI SHALL resolve artifact paths, templates, required content, and dependency readiness from the configured local schema. Required file artifacts MUST be non-empty, satisfy their template structure, and contain no unresolved template placeholders. Task artifacts MUST contain at least one valid checklist item.

#### Scenario: Dependency is incomplete
- **WHEN** an artifact depends on another artifact that is not complete
- **THEN** status MUST report it blocked with the missing dependency rather than ready

#### Scenario: Required artifact is empty
- **WHEN** every required artifact path exists but one artifact has no accepted content
- **THEN** status and validate MUST reject apply readiness

### Requirement: Failure-safe synchronization and archive
Sync and archive SHALL prepare and validate every affected main specification before writing any accepted update. Archive MUST reject destination collisions before changing main specifications.

#### Scenario: Archive destination exists
- **WHEN** the dated archive destination already exists
- **THEN** archive MUST fail without changing main specs or the active change

### Requirement: Local artifact integrity doctor
Doctor SHALL verify published artifact metadata, the complete manifest file set, and portable content hashes without using an external source repository.

#### Scenario: Published contract drifts
- **WHEN** a manifested runtime file changes
- **THEN** local Doctor MUST report the exact drift and return unhealthy
