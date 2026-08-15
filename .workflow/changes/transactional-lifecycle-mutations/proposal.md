## Why

Deployment mutation is now preflighted and recoverable, but lifecycle publication still writes accepted capability files and sync receipts sequentially. A filesystem failure or process exit can leave only part of a multi-capability sync published, or leave main specs updated while archive remains active. Accepted specifications require the same deterministic failure boundary as deployment.

## What Changes

- Add one repository-local writer lock for lifecycle mutations, with safe stale-lock takeover after the owning process exits.
- Stage sync and archive outputs in a durable `.workflow/.transactions/<id>/` transaction containing a strict journal, original snapshots, and prepared content.
- Roll back caught failures immediately and recover interrupted prepared, committing, or committed transactions on the next mutation.
- Make Doctor report transaction or lock residue without modifying it.
- Add deterministic failpoints and cross-runtime regression coverage for partial write, receipt write, archive move, interruption recovery, and concurrent mutation.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `workflow-cli`: transactional sync/archive mutation, single-writer coordination, durable recovery, and transaction diagnostics.

## Impact

This changes the repository-owned PowerShell runtime, generated Codex artifact, local Doctor results, lifecycle state under `.workflow`, tests, and architecture documentation. It adds no command, skill, package, service, or network dependency.

## Non-goals

- No new lifecycle command or agent instruction.
- No compatibility layer for partially implemented transaction formats.
- No guarantee against physical disk corruption or external processes modifying the same files outside Workflow.
