## ADDED Requirements

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
