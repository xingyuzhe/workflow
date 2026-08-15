# New change contract

## Preconditions

- A unique change name and the `branch.md` contract.

## Inputs

- User intent, repository rules, current main specs, and the `workflow-contract` artifact contract.

## Outputs

- A new change using `workflow-contract`.
- The initial artifact scope requested by the user, produced in schema dependency order.

## Acceptance

- Each produced artifact satisfies the schema contract.
- Local workflow status recognizes the change and accurately reports its next artifact.
- Every touched capability directory is a complete `spec.md`/`design.md` pair.

## Stop conditions

- Stop for missing product decisions, conflicting source-of-truth content, or authority beyond creating the change.
