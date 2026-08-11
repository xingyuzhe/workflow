## ADDED Requirements

### Requirement: Neutral workflow source
The system SHALL treat `.workflow/` as the only source of truth for shared prompts, gates, rules, MCP definitions, metadata, and local workflow state. Cursor and Codex runtime files SHALL be generated outputs and SHALL NOT be read as fallback sources.

#### Scenario: Generate both clients
- **WHEN** init processes a valid `.workflow` source
- **THEN** it SHALL deterministically generate the Cursor and Codex runtime layouts from that source

#### Scenario: Reject unsupported source fields
- **WHEN** an MCP or rule definition contains an unknown field or invalid type
- **THEN** init SHALL fail with the source path and field name instead of silently dropping data

### Requirement: Single metadata and state authority
The system SHALL store version, manifest, and state only under `.workflow/`.

#### Scenario: Update local state
- **WHEN** workflow state is written
- **THEN** only `.workflow/state.json` SHALL be updated
