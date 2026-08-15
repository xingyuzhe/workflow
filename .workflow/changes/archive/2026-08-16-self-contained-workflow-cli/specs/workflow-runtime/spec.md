## MODIFIED Requirements

### Requirement: Client-specific discovery adapters
Cursor SHALL receive `/workflow:*` commands and one always-applied router. Codex SHALL receive a concise `$workflow` skill, AGENTS managed routing, and generated references. Neither adapter SHALL be authoritative over the other. Routing SHALL cover explicit workflow lifecycle intent and failures within an active lifecycle operation; it SHALL NOT capture unrelated bugs or test failures.

#### Scenario: Lifecycle request
- **WHEN** a request clearly maps to a workflow lifecycle operation
- **THEN** the client adapter SHALL route it to the corresponding neutral contract

#### Scenario: Ordinary debugging request
- **WHEN** a bug or test failure is unrelated to an active workflow lifecycle operation
- **THEN** the workflow adapter MUST NOT require the workflow skill or a shared debug gate

### Requirement: Neutral state
Lifecycle status SHALL be derived from local workflow configuration, schema, changes, specs, and task content. No external command or optional cache SHALL override repository files.

#### Scenario: Multiple active changes
- **WHEN** an operation cannot uniquely select one of multiple active changes
- **THEN** it MUST require an explicit change name rather than guessing or consulting external state
