---
name: implementation-mode
description: Choose how to implement an OpenSpec change — direct tasks, plan files, or parallel subagents. Use when the user wants to start coding or implement a change and the path is unclear.
---

# Implementation Mode

Decide **how** to implement before diving into code. Announce: "Using implementation-mode to choose an execution path."

## When to use

- User says implement / start coding / apply / run the tasks
- Multiple execution skills could apply (`openspec-apply-change`, `executing-plans`, `subagent-driven-development`)
- Skip this skill if the user already named a specific path (e.g. `/opsx:apply`, "use executing-plans")

## Steps

1. **Identify the change**
   - Infer from context, or run `openspec list --json` and 向用户提问确认
   - Confirm design artifacts exist (`openspec status --change "<name>" --json`). If blocked / missing artifacts, suggest `/opsx:continue` and stop.

2. **Detect platform constraints**
   - If `subagent-driven-development` helper scripts need Git Bash and it is unavailable (typical plain PowerShell on Windows), treat option C as unavailable and note the fallback.

3. **向用户提问确认**（单次，三选一）:

```
How should we implement this change?

A) Follow OpenSpec tasks directly (recommended for most changes)
   → openspec-apply-change

B) Execute existing plan files under docs/plans/
   → executing-plans
   (Use when plans were already expanded with writing-plans)

C) Parallel subagent per task (large changes)
   → subagent-driven-development
   (Requires Git Bash; on Windows without Git Bash, falls back to B)
```

4. **Route**
   - A → load and follow `openspec-apply-change`
   - B → load and follow `executing-plans`
   - C → if Git Bash available, load `subagent-driven-development`; else warn and use `executing-plans`

5. **Do not** start coding inside this skill — only select and hand off.
