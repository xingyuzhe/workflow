## ADDED Requirements

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
