# design-review Specification

## Purpose
TBD - created by archiving change workflow-v2. Update Purpose after archive.
## Requirements
### Requirement: Grilling as pack short file
Design review (grilling) SHALL be delivered as a short pack file at `.cursor/workflow/pack/prompts/grill.md`, not as a standalone Superpowers-style skill framework. The grilling command or intent SHALL load this file before questioning the user.

#### Scenario: Start grill
- **WHEN** the user invokes design review / grilling
- **THEN** the agent MUST read `pack/prompts/grill.md` and follow its questioning protocol

### Requirement: Structured review notes
When grilling produces actionable decisions or open questions, the agent SHALL write or update `openspec/changes/<name>/review-notes.md` with structured findings. Review notes SHALL NOT replace proposal, design, or specs as the source of truth for requirements.

#### Scenario: Grill yields decisions
- **WHEN** grilling closes a design decision
- **THEN** the decision MUST be reflected in the authoritative artifact (usually change design) and MAY be summarized in `review-notes.md`

### Requirement: Optional before apply
Grilling SHALL be optional by default. The apply path SHALL NOT hard-block solely because grilling was skipped, unless the user or change explicitly required it.

#### Scenario: Apply without prior grill
- **WHEN** the user runs apply on a change that was never grilled
- **THEN** apply MUST proceed unless an explicit project rule requires grilling first

