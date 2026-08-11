---
name: openspec-workflow
description: Run the shared OpenSpec lifecycle, including exploring, creating, fast-forwarding, continuing, reviewing, applying, verifying, syncing, archiving, and diagnosing changes. Use for opsx commands (both `/opsx:name` and legacy `/opsx-name` forms), OpenSpec artifacts, implementing an active change, workflow doctor checks, or failures encountered during apply.
---

# OpenSpec workflow

Resolve the requested operation from the user intent or repository `AGENTS.md`.

1. Read `references/prompts/<operation>.md` completely.
2. For `new` and `ff`, also read `references/prompts/branch.md`.
3. For `archive`, also read `references/prompts/finish.md`.
4. For `apply`, read every file in `references/gates/` before writing production code and obey them as mandatory rules.
5. On a test failure, error, or unexpected behavior, read and follow `references/gates/debug.md`.
6. Read `.agents/workflow/state.json` when present, then reconcile it with `openspec status`; CLI output is authoritative.

Treat `/opsx:<operation>`, `/opsx-<operation>`, `$openspec-workflow <operation>`, and a clear natural-language request as equivalent.

Do not hand-edit `openspec/config.yaml`. Keep every capability's `spec.md` and `design.md` paired. Respect `docs/ssot.md`, `openspec/config.yaml`, and the context files returned by `openspec instructions`. Stop for the user's decision where a prompt explicitly requires one.
