## 1. Transaction protocol

- [x] 1.1 Implement strict journal validation, safe repository-relative targets, durable snapshots, staged replacements, and phase transitions.
- [x] 1.2 Implement exclusive lifecycle locking, stale-lock takeover, residue cleanup, and deterministic interrupted-transaction recovery.

## 2. Lifecycle integration

- [x] 2.1 Commit every sync capability pair and receipt through one transaction with caught-failure rollback.
- [x] 2.2 Commit archive sync outputs and the active-to-archive move through one transaction, restoring the active change on failure.
- [x] 2.3 Make Doctor report active/stale lock and transaction residue without mutation.

## 3. Verification and documentation

- [x] 3.1 Add guarded failpoints and regression tests for partial writes, receipt failure, archive move failure, interruption recovery, unsafe journals, and concurrent writers.
- [x] 3.2 Document the lifecycle transaction boundary without adding commands or agent operating instructions.
- [x] 3.3 Rebuild the Codex artifact and pass PowerShell 7, Windows PowerShell 5.1, Source Doctor, deterministic generation, and clean-worktree checks.
