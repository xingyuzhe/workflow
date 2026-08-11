# Fast-forward contract

## Preconditions

- A unique change name and the `branch.md` contract.

## Inputs

- User intent, repository rules, current main specs, and the `workflow-spec` artifact contract.

## Outputs

- A new or existing change with every artifact required for apply readiness.

## Acceptance

- OpenSpec status reports the change apply-ready.
- All artifacts satisfy schema dependencies and ownership.
- Every touched capability directory is a complete `spec.md`/`design.md` pair.

## Stop conditions

- Stop when a missing decision would materially change requirements or design.
- Do not begin implementation unless the user also authorized apply.
