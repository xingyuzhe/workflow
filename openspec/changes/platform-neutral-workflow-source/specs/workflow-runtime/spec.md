## MODIFIED Requirements

### Requirement: Neutral runtime pack and state
Workflow prompts and gates SHALL originate from `.workflow/pack`. Runtime state SHALL be read from and written to `.workflow/state.json`, with OpenSpec CLI status remaining authoritative.

#### Scenario: Client loads a prompt
- **WHEN** Cursor or Codex invokes an OpenSpec lifecycle operation
- **THEN** its generated adapter SHALL resolve content originating from `.workflow/pack`

#### Scenario: State conflicts with CLI
- **WHEN** `.workflow/state.json` disagrees with OpenSpec status
- **THEN** the CLI result SHALL win
