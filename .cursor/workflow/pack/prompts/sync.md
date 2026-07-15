# Sync specs

Sync delta specs from a change into main `openspec/specs/`.

## Steps

1. Identify change name; confirm deltas exist under `openspec/changes/<name>/specs/`.
2. For **each** capability being synced:
   - Create/update `openspec/specs/<capability>/spec.md`
   - Create/update `openspec/specs/<capability>/design.md`
   - **Never** publish a main capability with only one of the two files.
3. If OpenSpec CLI archive/sync only wrote `spec.md`, **manually copy/merge `design.md`** from the change (or archive) before finishing.
4. Run pair check:
   ```powershell
   pwsh -File scripts/doctor.ps1
   ```
   Doctor fails on incomplete pairs — fix before claiming sync done.

## Done when

- Main `openspec/specs/<capability>/` has both files for every synced capability.
- `doctor.ps1` passes (or only fails for unrelated reasons you report).
