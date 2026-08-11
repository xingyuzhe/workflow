---
name: openspec-workflow
description: Run the shared OpenSpec lifecycle, including exploring, creating, fast-forwarding, continuing, reviewing, applying, verifying, syncing, archiving, and diagnosing workflow installations. Use for opsx commands, OpenSpec artifacts, active-change implementation, or failures within an active lifecycle operation. Do not use for unrelated bugs or test failures.
---

# OpenSpec workflow

Resolve the lifecycle operation from user intent or repository `AGENTS.md`.

1. Read `references/prompts/<operation>.md` completely.
2. Load any contract explicitly referenced by that operation.
3. For `new` and `ff`, also read `references/prompts/branch.md`.
4. For `archive`, also read `references/prompts/finish.md`.
5. Reconcile optional `.workflow/state.json` with OpenSpec status; OpenSpec is authoritative.

Treat `/opsx:<operation>`, `/opsx-<operation>`, `$openspec-workflow <operation>`, and equivalent lifecycle intent as aliases.

Follow repository rules and the selected operation's inputs, outputs, acceptance, stop conditions, and authority. Let the agent choose its method unless a project rule, artifact contract, tool protocol, or safety boundary constrains it.
