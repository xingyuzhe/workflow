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
Doctor SHALL verify published artifact metadata, the complete manifest file set, portable content hashes, and absence of supported legacy workflow residue without using an external source repository. Legacy residue SHALL include the old project-data root, old Codex skill, `.openspec.yaml` below `.workflow/changes`, the exact former Cursor workflow namespace, fixed opsx commands, and an old-marker router. Doctor MUST preserve unrelated and current Cursor content.

#### Scenario: Published contract drifts
- **WHEN** a manifested runtime file changes
- **THEN** local Doctor MUST report the exact drift and return unhealthy

#### Scenario: Legacy metadata remains
- **WHEN** an active or archived change contains `.openspec.yaml`
- **THEN** local Doctor MUST report the repository-relative metadata path and leave it unchanged

#### Scenario: Legacy Cursor runtime remains
- **WHEN** the repository contains the former `.cursor/workflow` namespace or a fixed opsx command
- **THEN** local Doctor MUST report the exact residue

#### Scenario: Current Cursor adapter remains
- **WHEN** the repository contains current `/workflow:*` commands or a router without legacy markers
- **THEN** local Doctor MUST NOT report those files as legacy residue

### Requirement: Unambiguous delta semantics
Before synchronization writes, the CLI SHALL validate requirement-name uniqueness and the semantic preconditions of every delta operation against the current accepted specification. Conflicting rename targets and incompatible repeated operations MUST be rejected.

#### Scenario: Rename target already exists
- **WHEN** a delta renames requirement `Alpha` to an existing, different requirement `Beta`
- **THEN** sync MUST fail without changing the accepted spec or design

#### Scenario: Duplicate requirement names
- **WHEN** a main or delta specification contains duplicate requirement names
- **THEN** validate and sync MUST report the duplicate names

### Requirement: Equivalent replay
Synchronization MAY accept an operation whose result is already published only when replay produces equivalent accepted content. It MUST NOT use idempotence to hide a conflicting existing requirement.

#### Scenario: Repeat successful sync
- **WHEN** the same validated delta is synchronized twice
- **THEN** the second run MUST leave the accepted specification unchanged and succeed

### Requirement: Schema-role-driven lifecycle
The CLI SHALL select document, task-list, and capability-delta behavior from schema-declared artifact kinds. Capability publication roots MUST come from schema metadata rather than a fixed artifact ID or `specs/` path.

#### Scenario: Custom artifact identifiers
- **WHEN** a valid schema uses non-default IDs for its task list and capability deltas
- **THEN** status, validate, sync, and archive MUST operate from their declared kinds and paths

### Requirement: Durable lifecycle transaction
The CLI SHALL publish every sync or archive mutation through a strict repository-local transaction that snapshots all affected targets and stages all replacements before the first target mutation.

#### Scenario: Multi-capability write fails
- **WHEN** a sync fails after at least one capability target was changed
- **THEN** every affected main specification, design, and sync receipt MUST be restored byte-for-byte

### Requirement: Interrupted mutation recovery
Before starting a lifecycle mutation, the CLI SHALL recover every validated incomplete transaction. It MUST discard prepared transactions, roll back committing transactions, and retain the target state of committed transactions while removing their residue.

#### Scenario: Process exits during commit
- **WHEN** the mutating process exits after changing a target but before marking the transaction committed
- **THEN** the next sync or archive MUST restore the pre-transaction state before starting new work

### Requirement: Single lifecycle writer
The CLI SHALL allow only one sync or archive writer per repository. It MUST reject a second writer while the first owns the exclusive lock and MUST safely take over a stale lock left after process exit.

#### Scenario: Concurrent sync starts
- **WHEN** one process holds the lifecycle mutation lock and another starts sync or archive
- **THEN** the second process MUST fail before creating a transaction or changing a lifecycle target

### Requirement: Transactional archive boundary
Archive SHALL include accepted-spec publication, receipt mutation, active change removal, and archive destination creation in one recoverable transaction.

#### Scenario: Archive move fails after sync writes
- **WHEN** archive cannot complete its active-to-archive move after accepted specs changed
- **THEN** accepted specs MUST be restored and the active change MUST remain complete and unarchived

### Requirement: Read-only transaction diagnosis
Doctor SHALL report lifecycle lock or transaction residue and SHALL NOT acquire, delete, restore, or otherwise mutate transaction state.

#### Scenario: Interrupted transaction exists
- **WHEN** Doctor encounters a transaction left in any phase
- **THEN** it MUST report the repository unhealthy and leave every transaction file unchanged
