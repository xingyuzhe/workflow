# workflow-runtime Specification

## Purpose

Expose one OpenSpec lifecycle consistently through Cursor and Codex.

## Requirements

### Requirement: Neutral prompt pack
All lifecycle prompts and gates SHALL originate from `.workflow/pack`. Cursor commands and router SHALL load that path; Codex skill references SHALL be generated from the same files.

#### Scenario: Apply from either client
- **WHEN** apply is invoked through Cursor or Codex
- **THEN** the agent SHALL load the same apply prompt and quality gates originating from `.workflow/pack`

### Requirement: Client-specific discovery adapters
Cursor SHALL receive `/opsx:*` commands and one always-applied router. Codex SHALL receive a concise skill, AGENTS managed routing, and generated references. Neither adapter SHALL be authoritative over the other.

#### Scenario: Natural-language lifecycle request
- **WHEN** a request clearly maps to an operation
- **THEN** the client adapter SHALL route it to the corresponding neutral prompt

### Requirement: Neutral state
Local phase state SHALL be stored only in `.workflow/state.json` with `active_change`, `phase`, `branch`, and `updated_at`. OpenSpec CLI status SHALL remain authoritative and missing state SHALL not block work.

#### Scenario: State conflict
- **WHEN** local state disagrees with OpenSpec status
- **THEN** CLI output SHALL win

### Requirement: Short branch and finish prompts
Branch and finish SHALL remain short reusable prompts rather than quality gates. New/ff SHALL load branch; archive SHALL load finish.

#### Scenario: Start change work
- **WHEN** a new change is started
- **THEN** the branch prompt SHALL be followed before implementation
