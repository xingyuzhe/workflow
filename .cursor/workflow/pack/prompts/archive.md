# Archive change

Archive a completed change and keep main specs paired.

## Steps

1. Confirm tasks complete (`openspec status`) and verify done (or user accepts residual risk).
2. Archive with OpenSpec CLI, e.g.:
   ```text
   openspec archive <name> -y
   ```
3. **Pairing gate:** after archive, inspect `openspec/specs/<capability>/`. If any capability has `spec.md` without `design.md` (or the reverse), copy the missing file from `openspec/changes/archive/<dated-name>/specs/<capability>/` immediately.
4. Run `pwsh -File scripts/doctor.ps1` — must not report `spec/design pair incomplete`.
5. Clear stale local state: delete `.cursor/workflow/state.json`, or set `active_change`/`phase`/`branch` to null — it is **not** authoritative vs `openspec status`/`list`.
6. Load `finish.md` for merge / PR / keep / discard. Wait for the user.

## Done when

- Change lives under `openspec/changes/archive/`.
- Main specs for this change are fully paired.
- Local `state.json` no longer points at the archived change.
- User has been presented finish options.
