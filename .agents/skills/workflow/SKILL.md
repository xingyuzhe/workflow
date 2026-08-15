---
name: workflow
description: Run the repository-owned workflow lifecycle, including exploring, creating, fast-forwarding, continuing, reviewing, applying, verifying, syncing, archiving, and diagnosing installations. Use for workflow commands, change artifacts, active-change implementation, or failures within an active lifecycle operation. Do not use for unrelated bugs or test failures.
---

# Workflow

Resolve the lifecycle operation from user intent or repository `AGENTS.md`.

1. Read `references/prompts/<operation>.md` completely.
2. Load any contract explicitly referenced by that operation.
3. For `new` and `ff`, also read `references/prompts/branch.md`.
4. For `archive`, also read `references/prompts/finish.md`.
5. Use `.agents/skills/workflow/bin/workflow.ps1` for local status, instructions, validation, sync, archive, and doctor operations; repository files are authoritative.

Treat `/workflow:<operation>`, `/workflow-<operation>`, `$workflow <operation>`, and equivalent lifecycle intent as aliases.

This workflow is self-contained. Never install, download, discover, or invoke an external lifecycle CLI or package. A missing local CLI is an invalid workflow installation.

Follow repository rules and the selected operation's inputs, outputs, acceptance, stop conditions, and authority. Let the agent choose its method unless a project rule, artifact contract, tool protocol, or safety boundary constrains it.
