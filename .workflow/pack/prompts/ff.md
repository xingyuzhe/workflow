# Fast-forward change

Create **all** apply-ready artifacts in one pass: proposal → specs (pairs) → design → tasks.

## Steps

1. Follow `branch.md` (`change/<name>`).
2. Ensure schema is **workflow-spec**.
3. Loop until apply-ready:
   ```text
   openspec status --change "<name>"
   openspec instructions <next-artifact> --change "<name>"
   ```
   Write each artifact completely before moving on.
4. **Specs:** every `specs/<capability>/` MUST contain `spec.md` **and** `design.md` created together. SSOT: `openspec/config.yaml` + `docs/ssot.md`.
5. Stop when status shows apply-ready. Offer `/opsx:grill` (optional) then `/opsx:apply`.

## Done when

- `openspec status --change "<name>"` is apply-ready.
- No capability directory lacks a design companion.
- User has been offered grill vs apply (do not start coding until they choose apply / implement).
