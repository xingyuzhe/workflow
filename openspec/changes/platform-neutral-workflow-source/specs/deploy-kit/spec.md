## MODIFIED Requirements

### Requirement: Platform-neutral install
Init SHALL deploy `.workflow` as the canonical source and generate Cursor and Codex runtime assets from it. Init SHALL remove superseded workflow-owned client artifacts and SHALL preserve project-owned content outside managed regions.

#### Scenario: Install into a project
- **WHEN** init runs with a valid source and target
- **THEN** the target SHALL contain one `.workflow` authority and deterministic Cursor/Codex adapters

### Requirement: Read-only doctor and explicit repair
Doctor SHALL be read-only by default. It SHALL validate canonical schemas, generated content, managed blocks, JSON/TOML syntax, spec/design pairing, and OpenSpec configuration drift. A `-Fix` invocation SHALL regenerate only workflow-owned outputs and then rerun strict validation.

OpenSpec CLI resolution SHALL be validated when the CLI is available. When it is unavailable, Doctor SHALL still validate the project-local schema files without using a machine-specific executable fallback.

#### Scenario: Detect drift
- **WHEN** a generated adapter differs from the expected output
- **THEN** default doctor SHALL fail without changing any file

#### Scenario: Repair drift
- **WHEN** doctor runs with `-Fix`
- **THEN** it SHALL repair workflow-owned outputs, preserve project-owned surroundings, and report the result of a subsequent strict check
