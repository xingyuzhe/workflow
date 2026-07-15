# TDD Gate (MUST for logic changes)

## When required
- Behavioral / logic code changes: **MUST** RED → GREEN → REFACTOR.
- Not required: pure docs, config-only, renames, version bumps.
- Unsure? **Ask the user** before writing production code.

## Iron law
No production code without a failing test first. Watch the test fail for the right reason, then implement the minimum to pass, then refactor while green.

## Docs-only
If the task is documentation-only, skip this gate and note that in the session output.
