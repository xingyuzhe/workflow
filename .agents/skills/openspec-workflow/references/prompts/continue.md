# Continue change

Advance the **next incomplete** artifact for an existing change.

## Steps

1. Resolve change name (argument, `state.json`, or `openspec list`).
2. Inspect:
   ```text
   openspec status --change "<name>"
   openspec instructions <artifact> --change "<name>"
   ```
3. Write only the next required artifact (or the user-specified one).
4. If artifact is **specs**: for each capability being added/updated, write `spec.md` and `design.md` together. Incomplete pairs are not done.
5. Respect SSOT (`openspec/config.yaml`, `docs/ssot.md`).
6. Update `state.json` phase when useful.

## Done when

- The targeted artifact is complete per `openspec status`, **or**
- Specs work left every touched capability with both `spec.md` and `design.md`.
