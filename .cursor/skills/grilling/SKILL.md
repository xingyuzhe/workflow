---
name: grilling
description: Grill the user relentlessly about a plan or design. Use when the user wants to stress-test a plan before building, or uses any 'grill' trigger phrases.
---

# Grilling — structured design review

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

## Inputs

Locate the active OpenSpec change (from conversation, `/opsx:*` argument, or `openspec list --json`). Then run:

```bash
openspec status --change "<name>" --json
```

Use `changeRoot` / `artifactPaths` to load artifacts (do **not** use `contextFiles` from apply instructions).

| Artifact | Required? | Review focus |
|----------|-----------|--------------|
| proposal | Required | Why, scope, non-goals, capabilities |
| design (change-level) | Required | Cross-cutting architecture, trade-offs, risks |
| specs/*/spec.md | Required | Behaviors, edge cases, acceptance |
| specs/*/design.md | Required companion | Per-capability module design (paired with each spec) |
| tasks.md | Optional | Scope of implementation only — do not re-plan tasks here |

If required artifacts are missing (including any capability lacking `design.md`), stop and suggest `/opsx:continue` before grilling.

## Outputs

After the review (or when the user pauses), write:

`openspec/changes/<name>/review-notes.md`

Template:

```markdown
# Review notes: <change-name>

**Date:** <ISO date>
**Status:** shared-understanding | in-progress | blocked

## Confirmed decisions
- ...

## Open questions
- Question — *recommended: ...*

## Risks
| Risk | Severity | Mitigation |
|------|----------|------------|
| ... | high/medium/low | ... |

## Artifact updates needed
- [ ] proposal.md — ...
- [ ] design.md — ...
- [ ] specs/... — ...

## Alignment summary
<1 short paragraph>
```

Update this file as decisions land; do not wait until the very end if the session is long.

## Protocol

1. Read proposal, design, and specs from the change directory.
2. Walk the design tree: **one question per decision point**.
3. Look up codebase **facts**; ask the user only for **decisions**.
4. After each major section (proposal / design / specs), briefly summarize alignment gaps.
5. Do **not** enact the plan or start implementation until the user confirms shared understanding.
6. Write/update `review-notes.md` before handing off to implementation.

## Style rules

- Ask questions **one at a time**, waiting for feedback before continuing. Asking multiple questions at once is bewildering.
- For each question, provide your **recommended answer**.
- Prefer concrete options over open-ended essays when the decision space is small.
