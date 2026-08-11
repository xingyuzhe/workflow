# Explore

Think through ideas **before** creating or changing artifacts. Do not implement code unless the user explicitly asks.

## Steps

1. Clarify the problem, constraints, and success criteria (ask if missing).
2. Optionally inspect existing work:
   ```text
   openspec list
   openspec list --specs
   openspec status --change "<name>"
   ```
3. Compare 2–3 approaches with trade-offs; recommend one.
4. If the user wants to proceed: suggest `/opsx:new` or `/opsx:ff` (or continue an existing change). Do **not** create artifacts in explore unless asked.

## Done when

- User has a clear recommended next command/action, or explicitly pauses.
