# Archive contract

## Preconditions

- The user explicitly authorized archive.
- Verification passed, or the user explicitly accepted recorded residual risk.

## Inputs

- Completed change, repository-local workflow status, and main specs.

## Outputs

- Change moved under `.workflow/changes/archive/`.
- Accepted deltas represented in complete main capability pairs.
- `finish.md` presented when branch disposition remains undecided.

## Acceptance

- Local workflow status no longer reports the change as active.
- Doctor passes after archive.
- Main specs and archived artifacts are coherent.

## Stop conditions

- Stop before archive when authorization, verification disposition, or spec synchronization is unresolved.

## Authority

- Archive does not authorize merge, push, or branch deletion.
