---
name: openspec-apply-change
description: Implement tasks from an OpenSpec change. Use when the user wants to start implementing, continue implementation, or work through tasks.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.2.0"
---

Implement tasks from an OpenSpec change.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **Select the change**

   If a name is provided, use it. Otherwise:
   - Infer from conversation context if the user mentioned a change
   - Auto-select if only one active change exists
   - If ambiguous, run `openspec list --json` to get available changes and use the **AskUserQuestion tool** to let the user select

   Always announce: "Using change: <name>" and how to override (e.g., `/opsx:apply <other>`).

2. **Ensure isolated workspace (REQUIRED)**

   Before starting implementation, ensure we're on an isolated branch:
   - Check if current branch matches `change/<name>` pattern
   - If not on the right branch: use `branching-strategy` to create one with branch `change/<name>`
   - If on the wrong branch: warn the user and ask to confirm before proceeding

   **IMPORTANT**: Do NOT implement directly on main/master. Always isolate first.

3. **Check status to understand the schema**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to understand:
   - `schemaName`: The workflow being used (e.g., "spec-driven")
   - Which artifact contains the tasks (typically "tasks" for spec-driven, check status for others)

4. **Get apply instructions**

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   This returns:
   - Context file paths (varies by schema - could be proposal/specs/design/tasks or spec/tests/implementation/docs)
   - Progress (total, complete, remaining)
   - Task list with status
   - Dynamic instruction based on current state

   **Handle states:**
   - If `state: "blocked"` (missing artifacts): show message, suggest using openspec-continue-change
   - If `state: "all_done"`: congratulate, suggest archive
   - Otherwise: proceed to implementation

5. **Read context files**

   Read the files listed in `contextFiles` from the apply instructions output.
   The files depend on the schema being used:
   - **spec-driven**: proposal, specs, design, tasks
   - Other schemas: follow the contextFiles from CLI output

6. **Show current progress**

   Display:
   - Schema being used
   - Progress: "N/M tasks complete"
   - Remaining tasks overview
   - Dynamic instruction from CLI

7. **Optional: Expand tasks into atomic steps**

   Before starting implementation, assess task complexity. If tasks involve non-trivial code logic, offer to expand them using the `writing-plans` methodology:

   ```
   These tasks can be expanded into atomic TDD steps for more precise execution.
   Expand tasks before starting? (recommended for complex logic tasks)
   ```

   If the developer agrees:
   - Use `writing-plans` to generate plans under `docs/plans/YYYY-MM-DD-<change-name>/<task-name>.md`
   - `<change-name>` MUST match the OpenSpec change directory name at `openspec/changes/<change-name>/`
   - `<task-name>` is the slugified title of the task being expanded (e.g., "Add user validation" → `add-user-validation.md`)
   - Each change gets its own dated directory; each task plan is a separate file within it
   - The plan reads specs, design, and tasks from the change artifacts as input
   - Each task from `tasks.md` is expanded into atomic steps (write test → verify fail → implement → verify pass → commit)
   - Implementation then follows the expanded plan while still marking checkboxes in `tasks.md`

   If the developer declines, proceed directly with the tasks as written.

8. **Implement tasks (loop until done or blocked)**

   For each pending task:
   - Show which task is being worked on
   - **Follow TDD when the task involves code logic** (see Quality Integration below)
   - Keep changes minimal and focused
   - **Verify before marking complete**: run relevant tests, confirm output (see Quality Integration below)
   - Mark task complete in the tasks file: `- [ ]` → `- [x]`
   - Continue to next task

   **Pause if:**
   - Task is unclear → ask for clarification
   - Implementation reveals a design issue → suggest updating artifacts
   - Error or blocker encountered → use `systematic-debugging` skill (see Quality Integration below)
   - User interrupts

   **Review checkpoint:** After every 3 completed tasks (or at end if fewer), run the full test suite and report status before continuing.

9. **On completion or pause, show status**

   Display:
   - Tasks completed this session
   - Overall progress: "N/M tasks complete"
   - Test suite status (pass/fail count)
   - If paused: explain why and wait for guidance
   - If all done: proceed to **Completion Sequence** below

**Output During Implementation**

```
## Implementing: <change-name> (schema: <schema-name>)

Working on task 3/7: <task description>
[...implementation happening...]
✓ Task complete

Working on task 4/7: <task description>
[...implementation happening...]
✓ Task complete
```

**Output On Completion**

```
## Implementation Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 7/7 tasks complete ✓
**Tests:** <pass>/<total> passing

### Completed This Session
- [x] Task 1
- [x] Task 2
...
```

**Completion Sequence (developer decides each step)**

When all tasks are done, guide through these steps in order. The agent presents each step and waits for developer decision — never auto-execute merge or archive.

1. **Verify** — Run `openspec-verify-change` to check artifact-implementation alignment. Present results and ask whether to proceed or fix issues.

2. **Integrate code** — Run `finishing-a-development-branch` which presents 4 options (merge/PR/keep/discard). Wait for developer to choose.

3. **Archive change** — Run `openspec-archive-change` which checks completion status, offers delta spec sync, and confirms before archiving. Wait for developer to confirm.

Each step requires an explicit developer decision. If the developer declines or defers at any step, stop and respect their choice.

**Output On Pause (Issue Encountered)**

```
## Implementation Paused

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 4/7 tasks complete

### Issue Encountered
<description of the issue>

**Options:**
1. <option 1>
2. <option 2>
3. Other approach

What would you like to do?
```

**Quality Integration (Superpowers)**

The apply phase integrates the following superpowers quality skills. These enhance the implementation loop without altering the OpenSpec artifact workflow.

**TDD (test-driven-development) — applies when writing code**

When a task involves code logic changes (not pure config/docs/rename), follow RED-GREEN-REFACTOR:
1. Write a failing test that verifies the expected behavior
2. Write minimal code to make the test pass
3. Refactor while keeping tests green

TDD is NOT required for: pure config changes, documentation updates, file moves/renames, dependency version bumps. When in doubt, lean toward writing a test.

**verification-before-completion — REQUIRED before marking complete**

Before changing `- [ ]` to `- [x]`, you MUST have runtime evidence that the task is actually complete:
- Run relevant tests and confirm they pass
- If no automated tests exist, perform manual verification and record output
- Never claim completion with phrases like "should be fine" or "looks correct"

**systematic-debugging — triggered on issues**

When encountering errors, test failures, or unexpected behavior during implementation:
1. Do not attempt random fixes
2. Read error messages, reproduce the issue, inspect recent changes
3. Form a hypothesis, write a minimal test
4. If 3 fix attempts fail, pause and report — it may be a design-level issue, suggest updating OpenSpec artifacts

**code review — recommended every 3 tasks**

After every 3 completed tasks (or when all tasks are done), conduct a review:
- Run the full test suite
- Check whether changes align with specs/design
- If divergence is found, pause and suggest updating artifacts

**Guardrails**
- Keep going through tasks until done or blocked
- Always read context files before starting (from the apply instructions output)
- If task is ambiguous, pause and ask before implementing
- If implementation reveals issues, pause and suggest artifact updates
- Keep code changes minimal and scoped to each task
- Update task checkbox immediately after completing each task — but only after verification
- Pause on errors, blockers, or unclear requirements - don't guess
- Use contextFiles from CLI output, don't assume specific file names
- Never claim a task is complete without running verification first

**Fluid Workflow Integration**

This skill supports the "actions on a change" model:

- **Can be invoked anytime**: Before all artifacts are done (if tasks exist), after partial implementation, interleaved with other actions
- **Allows artifact updates**: If implementation reveals design issues, suggest updating artifacts - not phase-locked, work fluidly
- **Quality skills are always active**: TDD, verification, debugging skills apply whenever writing code, regardless of which OpenSpec phase you're in

**Integration**

**Required workflow skills:**
- **branching-strategy** — REQUIRED: Verify/create isolated workspace before implementation
- **finishing-a-development-branch** — REQUIRED in Completion Sequence for merge/PR/cleanup
