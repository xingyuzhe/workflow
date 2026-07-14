---
name: openspec-continue-change
description: Continue working on an OpenSpec change by creating the next artifact. Use when the user wants to progress their change, create the next artifact, or continue their workflow.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.5.0"
---

Continue working on a change by creating the next artifact.

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes sorted by most recently modified. Then use the 向用户提问确认 to let the user select which change to work on.

   Present the top 3-4 most recently modified changes as options, showing:
   - Change name
   - Schema (from `schema` field if present, otherwise "spec-driven")
   - Status (e.g., "0/5 tasks", "complete", "no tasks")
   - How recently it was modified (from `lastModified` field)

   Mark the most recently modified change as "(Recommended)" since it's likely what the user wants to continue.

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Verify isolated workspace (REQUIRED)**

   Before continuing work, verify we're on the correct isolated branch:
   - Check if current branch matches `change/<name>` pattern
   - If not on the right branch: use `branching-strategy` to create one with branch `change/<name>`
   - If on the wrong branch: warn the user and ask to confirm before proceeding

   **IMPORTANT**: Do NOT work on change artifacts directly on main/master.

3. **Check current status**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to understand current state. The response includes:
   - `schemaName`: The workflow schema being used (e.g., "spec-driven")
   - `artifacts`: Array of artifacts with their status ("done", "ready", "blocked")
   - `isComplete`: Boolean indicating if all artifacts are complete
   - `planningHome`, `changeRoot`, `artifactPaths`, and `actionContext`: path and scope context. Use these instead of assuming repo-local paths.

4. **Act based on status**:

   ---

   **If all artifacts are complete (`isComplete: true`)**:
   - Congratulate the user
   - Show final status including the schema used
   - Suggest: "All artifacts created! You can now implement this change or archive it."
   - STOP

   ---

   **If artifacts are ready to create** (status shows artifacts with `status: "ready"`):
   - Pick the FIRST artifact with `status: "ready"` from the status output
   - Get its instructions:
     ```bash
     openspec instructions <artifact-id> --change "<name>" --json
     ```
   - Parse the JSON. The key fields are:
     - `context`: Project background (constraints for you - do NOT include in output)
     - `rules`: Artifact-specific rules (constraints for you - do NOT include in output)
     - `template`: The structure to use for your output file
     - `instruction`: Schema-specific guidance
     - `resolvedOutputPath`: Resolved path or pattern to write the artifact
     - `dependencies`: Completed artifacts to read for context
   - **Create the artifact file**:
     - Read any completed dependency files for context
     - Use `template` as the structure - fill in its sections
     - Apply `context` and `rules` as constraints when writing - but do NOT copy them into the file
     - Write to the `resolvedOutputPath` specified in instructions. If it is a glob pattern, choose the concrete file path using the schema instruction and the change's context
   - Show what was created and what's now unlocked
   - STOP after creating ONE artifact

   ---

   **If no artifacts are ready (all blocked)**:
   - This shouldn't happen with a valid schema
   - Show status and suggest checking for issues

5. **After creating an artifact, show progress**
   ```bash
   openspec status --change "<name>"
   ```

**Output**

After each invocation, show:
- Which artifact was created
- Schema workflow being used
- Current progress (N/M complete)
- What artifacts are now unlocked
- Prompt: "Want to continue? Just ask me to continue or tell me what to do next."
- If `design` was just completed (or all design-phase artifacts are done): also suggest **"Review the design before implementing? Say grill me"**

**Artifact Creation Guidelines**

The artifact types and their purpose depend on the schema. Use the `instruction` field from the instructions output to understand what to create.

Common artifact patterns:

**spec-driven schema** (proposal → specs → design → tasks):
- **proposal.md**: Ask user about the change if not clear. Fill in Why, What Changes, Capabilities, Impact.
  - The Capabilities section is critical - each capability listed will need a **spec + design pair**.
  - **Owns:** 为什么做、做什么、影响谁、能力清单。短、偏产品/范围。
  - **Does NOT own:** 文件结构、类型定义、节点图、接口签名（那些属于 design）。
- **specs/<capability>/spec.md**: Create one delta spec per capability listed in the proposal's Capabilities section (use the capability name, not the change name).
  - **Owns:** 可验证行为（SHALL + Scenario）。不写实现结构。
- **specs/<capability>/design.md** (**REQUIRED companion**): When creating or updating a capability's `spec.md`, **always create/update** `specs/<capability>/design.md` in the same step. Do not leave a capability with only `spec.md`.
  - **Owns (module SSOT):** 该模块的职责边界、文件结构、关键类型/接口、模块内算法/状态机、与邻接模块的**接口契约**。
  - If main `openspec/specs/<capability>/design.md` already exists, read it first; in a **change**, prefer a short **delta** section ("本次对该模块设计的变更") plus pointers, or a full updated draft only when the module design itself is being rewritten.
- **design.md** (change-level): Document **cross-cutting** technical decisions only.
  - **Owns:** 跨模块取舍、迁移步骤、共享约束、能力之间的协作关系。用链接/能力名引用模块，**不要**复制各模块的文件树或类型全文。
- **tasks.md**: Break down implementation into checkboxed tasks.

**Anti-duplication (SSOT — one fact, one home):**

| 内容 | 权威位置 | 其它文档怎么写 |
|------|----------|----------------|
| Why / 范围 / 非目标 / 能力清单 | `proposal.md` | change-level design 只写 "见 proposal"；模块 design 不重复 Why |
| 跨模块决策、迁移、共享约束 | change-level `design.md` | 模块 design 用一句话 + 决策 ID 引用（如 "见 change design D1"） |
| 模块职责、文件结构、类型、内部状态机 | `specs/<capability>/design.md` | change design 只列模块名 + 一句话影响，不贴长代码 |
| 可验证行为 / 场景 | `specs/<capability>/spec.md` | design 不写 WHEN/THEN；proposal 不写 SHALL 场景 |
| Purpose 一句话 | `spec.md` Purpose | 模块 design「职责」可有一句等价摘要，**禁止**把 Purpose 扩成第二份需求 |

**Hard rules:**
- 若两处出现同一段 >5 行的结构说明或类型定义 → 删掉非权威处，改为链接到权威文件。
- change-level `design.md` 的 Decisions 写「选了什么、为什么」；「改哪些文件/类型」落在对应 `specs/<cap>/design.md`。
- proposal 的 What Changes 用子弹列表；细节实现放到 design，不在 proposal 展开。

**Per-capability design companion rule (always):**
```
specs/<capability>/spec.md     ← requirements / scenarios
specs/<capability>/design.md   ← module design SSOT (MUST with the spec)
proposal.md                    ← why / scope / capabilities
design.md (change)             ← cross-cutting decisions only
```
Never finish the `specs` artifact while any listed capability is missing `design.md`.

**Guardrails**
- Create ONE artifact per invocation
- Always read dependency artifacts before creating a new one
- Never skip artifacts or create out of order
- If context is unclear, ask the user before creating
- Verify the artifact file exists after writing before marking progress
- Use the schema's artifact sequence, don't assume specific artifact names
- **IMPORTANT**: `context` and `rules` are constraints for YOU, not content for the file
  - Do NOT copy `<context>`, `<rules>`, `<project_context>` blocks into the artifact
  - These guide what you write, but should never appear in the output
- **Never work on change artifacts directly on main/master** — always verify branch isolation

**Integration**

**Required workflow skills:**
- **branching-strategy** — REQUIRED: Verify/create isolated workspace before continuing work
- **finishing-a-development-branch** — Used at end of change lifecycle for merge/PR/cleanup
