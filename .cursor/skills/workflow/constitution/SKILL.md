---
name: constitution
description: Full workflow discipline details — load when router skill-check needs Red Flags, Skill Types, Platform Adaptation, or User Instructions. Do not call as a primary workflow entry.
---

# Workflow Constitution

Load this only when the router needs detail beyond the always-applied Top-5 traps.

## Full Red Flags

These thoughts mean STOP — you are rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Read it. |

## Skill Types

**Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.

**Flexible** (patterns): Adapt principles to context.

The skill itself tells you which.

## Platform Adaptation

If skills reference platform-specific concepts (native worktree tools, etc.), adapt to Cursor's capabilities. When a skill mentions `EnterWorktree` or similar native tools, use the Cursor equivalent or fall back to manual git commands via Shell.

`subagent-driven-development` helper scripts require Git Bash. On Windows without Git Bash, use `executing-plans` instead.

## User Instructions

User instructions (CLAUDE.md, AGENTS.md, GEMINI.md, `.cursor/rules`, direct requests) take precedence over skills, which in turn override default behavior. Only skip skill workflows or instructions when your human partner has explicitly told you to.

## TDD Gray Area

When uncertain whether TDD applies to a task, 向用户提问确认. Never decide on your own. See `openspec-apply-change` Quality Integration and `test-driven-development` SKILL.md.
