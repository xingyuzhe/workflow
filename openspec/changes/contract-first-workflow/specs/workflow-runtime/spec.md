## MODIFIED Requirements

### Requirement: Neutral prompt pack
All lifecycle operation contracts and shared acceptance contracts SHALL originate from `.workflow/pack`. Cursor commands and router SHALL load that path; Codex skill references SHALL be generated from the same files. Operation contracts SHALL define delivery boundaries and SHALL NOT mandate generic reasoning, coding, testing, or debugging methods.

#### Scenario: Apply from either client
- **WHEN** apply is invoked through Cursor or Codex
- **THEN** both clients MUST consume the same apply and acceptance contracts originating from `.workflow/pack`

#### Scenario: Agent selects an implementation method
- **WHEN** no project rule, protocol, safety boundary, or active artifact constrains the implementation method
- **THEN** the shared workflow MUST leave method selection to the agent

### Requirement: Client-specific discovery adapters
Cursor SHALL receive `/opsx:*` commands and one always-applied router. Codex SHALL receive a concise skill, AGENTS managed routing, and generated references. Routing SHALL cover explicit OpenSpec lifecycle intent and failures within an active lifecycle operation; it SHALL NOT capture unrelated bugs or test failures.

#### Scenario: Ordinary debugging request
- **WHEN** a bug or test failure is unrelated to an active OpenSpec lifecycle operation
- **THEN** the workflow adapter MUST NOT require the OpenSpec skill or a shared debug gate

### Requirement: Short branch and finish prompts
Branch and finish SHALL define state and authority contracts rather than procedural scripts. New/ff SHALL load branch; archive SHALL load finish.

#### Scenario: Start change work
- **WHEN** a new change is started
- **THEN** branch state MUST satisfy the branch contract before implementation
