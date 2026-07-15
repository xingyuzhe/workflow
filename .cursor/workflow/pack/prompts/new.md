# New change

Create a new OpenSpec change under schema **workflow-spec**.

## Steps

1. Follow `branch.md` (default branch `change/<name>`). Do not work on `main`/`master`.
2. Create the change (CLI or equivalent) so it uses project default schema `workflow-spec` (`openspec/config.yaml`).
3. Produce artifacts in schema order. For each step:
   ```text
   openspec status --change "<name>"
   openspec instructions <artifact> --change "<name>"
   ```
   Then write the files that instructions require.
4. **Specs phase (hard rule):** for every capability under `openspec/changes/<name>/specs/<capability>/`, create **both** `spec.md` and `design.md` in the same step. Never leave only `spec.md`.
5. Respect SSOT: `docs/ssot.md` and `openspec/config.yaml` rules.
6. After each major artifact, optionally update `.cursor/workflow/state.json` (`active_change`, `phase`, `branch`).

## Done when

```text
openspec status --change "<name>"
```

shows all planning artifacts complete (or the user stops early). Specs directories that exist are paired (`spec.md` + `design.md`).
