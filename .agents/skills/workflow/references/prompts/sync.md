# Sync contract

## Preconditions

- An active or archived change has capability deltas to publish.

## Inputs

- Delta capability pairs and existing main specs.

## Outputs

- Main `.workflow/specs/<capability>/spec.md` and `design.md` updated together.

## Acceptance

- Published requirements and designs represent the accepted delta.
- No affected main capability has an incomplete pair.
- Doctor passes, or unrelated failures are reported without claiming a clean sync.

## Stop conditions

- Stop for conflicting main changes or ambiguous merge semantics.

## Authority

- Sync does not authorize archive, merge, or push.
