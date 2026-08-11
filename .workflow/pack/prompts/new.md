# New change contract

## Preconditions

- A unique change name and the `branch.md` contract.

## Inputs

- User intent, repository rules, current main specs, and the `workflow-spec` artifact contract.

## Outputs

- A new change using `workflow-spec`.
- The initial artifact scope requested by the user, produced in schema dependency order.
- Optional local state that points to the active change without replacing OpenSpec status.

## Acceptance

- Each produced artifact satisfies the schema contract.
- OpenSpec status recognizes the change and accurately reports its next artifact.
- Every touched capability directory is a complete `spec.md`/`design.md` pair.

## Stop conditions

- Stop for missing product decisions, conflicting source-of-truth content, or authority beyond creating the change.
