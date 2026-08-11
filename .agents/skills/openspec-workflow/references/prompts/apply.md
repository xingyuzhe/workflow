# Apply contract

Load `../gates/acceptance.md`.

## Preconditions

- An active change is apply-ready.
- Implementation is on a change branch satisfying `branch.md`.
- The user authorized implementation.

## Inputs

- Apply context returned by OpenSpec, all referenced artifacts, repository rules, and current code.

## Outputs

- Implementation that satisfies the active requirements and scenarios.
- Verification evidence for completed work.
- Task status that matches actual completion.

## Acceptance

- Every completed task satisfies the completion evidence contract.
- Relevant scenarios and project checks pass, or residuals are explicit and accepted.
- No unsupported scope, compatibility layer, or unrelated change is introduced.

## Stop conditions

- Stop for contradictory artifacts, missing material decisions, unavailable authority, or failed evidence that invalidates completion.

## Authority

- Apply does not authorize merge, push, archive, destructive branch operations, or unrelated external changes.
