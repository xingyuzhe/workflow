# Archive contract

## Preconditions

- The user explicitly authorized archive.
- Verification passed, or the user explicitly accepted recorded residual risk.

## Inputs

- Completed change, authoritative OpenSpec status, and main specs.

## Outputs

- Change moved under `openspec/changes/archive/`.
- Accepted deltas represented in complete main capability pairs.
- Optional local state no longer points to the archived change.
- `finish.md` presented when branch disposition remains undecided.

## Acceptance

- OpenSpec recognizes the archive.
- Doctor passes after archive.
- Main specs and archived artifacts are coherent.

## Stop conditions

- Stop before archive when authorization, verification disposition, or spec synchronization is unresolved.

## Authority

- Archive does not authorize merge, push, or branch deletion.
