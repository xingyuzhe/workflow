# Continue contract

## Preconditions

- An existing active change.

## Inputs

- Repository-local workflow status, the next artifact instructions, current artifacts, and repository rules.

## Outputs

- The next incomplete artifact, or the specific artifact requested by the user.

## Acceptance

- Local workflow status reports the targeted artifact as complete.
- The artifact satisfies schema ownership and dependency contracts.
- Every touched capability directory is a complete `spec.md`/`design.md` pair.

## Stop conditions

- Stop for artifact conflicts or a product decision that changes scope.
