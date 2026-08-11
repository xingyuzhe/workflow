# Verify change

Check implementation against change artifacts. Do **not** archive yet.

## Steps

1. ```text
   openspec status --change "<name>"
   ```
   Tasks should be complete (or list what remains).
2. Read proposal / design / `specs/*/spec.md` (+ companion `design.md`) and `tasks.md`.
3. Diff code vs requirements/scenarios; list gaps with file paths.
4. Confirm logic tasks followed TDD/verify gates (evidence in session). Note skips that were docs-only.
5. Optionally run project tests / `scripts/doctor.ps1` and record output.

## Done when

- You report **pass** or **fail** with concrete gaps.
- User decides: fix → re-apply, or proceed to archive despite residuals.
