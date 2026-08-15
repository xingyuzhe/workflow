## Context

`Sync-WorkflowChange` validates all logical results before writing, but then mutates each capability pair and the receipt in sequence. `archive` performs that sync before moving the change. Caught deployment failures already restore snapshots, while lifecycle mutations lack both caught-failure rollback and process-interruption recovery.

## Goals / Non-Goals

Goals:

- Make sync and archive all-or-nothing from the repository's observable lifecycle state.
- Recover deterministically after the mutating process exits in any commit phase.
- Reject concurrent writers and unsafe or malformed transaction data.
- Keep Doctor read-only and keep the existing CLI surface unchanged.

Non-goals:

- Coordinate unrelated tools that edit `.workflow/specs` directly.
- Add generic workflow advice or another skill.
- Preserve experimental transaction formats.

## Decisions

1. `.workflow/.mutation.lock` is an exclusive file-handle lock. A surviving handle means another writer is active. A lock file whose handle can be exclusively opened is stale and may be taken over by the next mutation.
2. Transactions live at `.workflow/.transactions/<guid>/`. `journal.json` uses strict JSON and repository-relative target paths. Every target records whether it existed and, when applicable, a byte-for-byte snapshot. Prepared replacement files are also stored inside the transaction.
3. Journal phases are `prepared`, `committing`, and `committed`. Recovery removes `prepared`, restores every target for `committing`, and keeps committed target state while removing `committed` residue.
4. Sync snapshots every affected `spec.md`, `design.md`, and the change `.sync.json`; it stages all replacements before entering `committing`.
5. Archive uses the same transaction and additionally snapshots the active change directory and archive destination. A move failure or interruption before `committed` restores main specs and leaves the change active.
6. Every mutation acquires the lock, recovers older transactions, prepares one new transaction, commits, marks it committed, and removes transaction residue before releasing the lock.
7. Doctor reports lock/transaction residue but never takes the lock or performs recovery. The next sync/archive performs recovery automatically.
8. Test-only failpoints require both `WORKFLOW_ENABLE_TEST_HOOKS=1` and an explicit `WORKFLOW_TEST_FAILPOINT`. They are not CLI options and are excluded from normal behavior.

## Risks / Trade-offs

- Snapshots consume temporary repository space proportional to affected specs and change artifacts.
- Multi-file atomicity is implemented through durable rollback/recovery rather than a filesystem primitive that does not exist across multiple paths.
- A stale lock is distinguished from an active writer through exclusive file access; hostile external processes remain outside scope.
