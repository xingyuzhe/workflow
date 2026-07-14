---
name: openspec-sync-specs
description: Sync delta specs from a change to main specs. Use when the user wants to update main specs with changes from a delta spec, without archiving the change.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.5.0"
---
Sync delta specs **and** per-capability design companions from a change to main specs.

This is an **agent-driven** operation - you will read delta specs/designs and directly edit main specs to apply the changes. This allows intelligent merging (e.g., adding a scenario without copying the entire requirement).

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes. Use the 向用户提问确认 to let the user select.

   Show changes that have delta specs (under `specs/` directory).

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Resolve change context**

   Run:
   ```bash
   openspec status --change "<name>" --json
   ```

3. **Find delta specs and design companions**

   Use `artifactPaths.specs.existingOutputPaths` from the status JSON as the list of delta spec files.

   For each delta `specs/<capability>/spec.md`, also look for the companion:
   - `specs/<capability>/design.md` (inside the change root)

   Each delta spec file contains sections like:
   - `## ADDED Requirements` - New requirements to add
   - `## MODIFIED Requirements` - Changes to existing requirements
   - `## REMOVED Requirements` - Requirements to remove
   - `## RENAMED Requirements` - Requirements to rename (FROM:/TO: format)

   If no delta specs found, inform user and stop.

   If a capability has `spec.md` but **no** `design.md` in the change:
   - Warn: "Missing per-capability design companion for <capability>"
   - Create a reasonable `specs/<capability>/design.md` from change-level `design.md` + codebase before syncing, or 向用户提问确认 whether to sync specs-only for that capability (default: **create the companion first**).

4. **For each delta capability, apply changes to main specs**

   For each repo-local capability delta spec path returned by the CLI:

   a. **Read the delta spec** to understand the intended changes

   b. **Read the main spec** at `openspec/specs/<capability>/spec.md` (may not exist yet)

   c. **Apply spec changes intelligently**:

      **ADDED Requirements:**
      - If requirement doesn't exist in main spec → add it
      - If requirement already exists → update it to match (treat as implicit MODIFIED)

      **MODIFIED Requirements:**
      - Find the requirement in main spec
      - Apply the changes - this can be:
        - Adding new scenarios (don't need to copy existing ones)
        - Modifying existing scenarios
        - Changing the requirement description
      - Preserve scenarios/content not mentioned in the delta

      **REMOVED Requirements:**
      - Remove the entire requirement block from main spec

      **RENAMED Requirements:**
      - Find the FROM requirement, rename to TO

   d. **Create new main spec** if capability doesn't exist yet:
      - Create `openspec/specs/<capability>/spec.md`
      - Add Purpose section (can be brief, mark as TBD)
      - Add Requirements section with the ADDED requirements

   e. **Sync per-capability design companion** (REQUIRED with the spec):
      - Target: `openspec/specs/<capability>/design.md`
      - If change has `specs/<capability>/design.md`:
        - If main design missing → create it from the change companion (full module design)
        - If main design exists → intelligently merge (update 职责/结构/类型/决策 sections touched by this change; preserve unrelated content)
      - If change companion was just created in step 3, sync that version
      - **Never** leave a newly created main capability with only `spec.md` and no `design.md`

5. **Show summary**

   After applying all changes, summarize:
   - Which capabilities were updated
   - Spec changes (requirements added/modified/removed/renamed)
   - Design companions created or updated

**Delta Spec Format Reference**

```markdown
## ADDED Requirements

### Requirement: New Feature
The system SHALL do something new.

#### Scenario: Basic case
- **WHEN** user does X
- **THEN** system does Y

## MODIFIED Requirements

### Requirement: Existing Feature
#### Scenario: New scenario to add
- **WHEN** user does A
- **THEN** system does B

## REMOVED Requirements

### Requirement: Deprecated Feature

## RENAMED Requirements

- FROM: `### Requirement: Old Name`
- TO: `### Requirement: New Name`
```

**Per-capability design companion (suggested skeleton)**

```markdown
# <capability> 模块设计

## 职责
（一句；不要复述 proposal Why）

## 文件结构
...

## 关键类型 / 接口
...

## 与其它模块的关系
（接口契约；跨模块取舍写「见 change design Dx」）

## 本次变更的设计决策
（仅本模块；跨模块决策不在此展开）
```

Do **not** paste proposal Why or the full change-level Decisions list into this file.

**Key Principle: Intelligent Merging**

Unlike programmatic merging, you can apply **partial updates**:
- To add a scenario, just include that scenario under MODIFIED - don't copy existing scenarios
- The delta represents *intent*, not a wholesale replacement
- Use your judgment to merge changes sensibly
- Same for design.md: merge section-level intent; don't blindly overwrite the whole module design

**Output On Success**

```
## Specs Synced: <change-name>

Updated main specs:

**<capability-1>**:
- Added requirement: "New Feature"
- Updated design.md (文件结构 / 关键类型)

**<capability-2>**:
- Created spec.md + design.md
- Added requirement: "Another Feature"

Main specs are now updated. The change remains active - archive when implementation is complete.
```

**Guardrails**
- Read both delta and main specs (and designs) before making changes
- Preserve existing content not mentioned in delta
- Spec and design companions stay paired: syncing a capability always considers both files
- If something is unclear, ask for clarification
- Show what you're changing as you go
- The operation should be idempotent - running twice should give same result
