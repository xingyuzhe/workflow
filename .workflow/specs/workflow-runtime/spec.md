# workflow-runtime Specification

## Purpose

Expose one self-contained, contract-first workflow lifecycle consistently through Cursor and Codex.

## Requirements

### Requirement: Neutral prompt pack
All lifecycle operation contracts and shared acceptance contracts SHALL originate from `.workflow/pack`. Generated client references SHALL derive from those files. Operation contracts SHALL define lifecycle boundaries and SHALL NOT mandate generic reasoning, coding, testing, or debugging methods.

#### Scenario: Apply from either client
- **WHEN** apply is invoked through Cursor or Codex
- **THEN** both clients MUST consume the same apply and acceptance contracts

#### Scenario: Agent selects an implementation method
- **WHEN** no project rule, protocol, safety boundary, or active artifact constrains the method
- **THEN** the shared workflow MUST leave method selection to the agent

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

### Requirement: Short branch and finish prompts
Branch and finish SHALL define state and authority contracts rather than procedural scripts. New/ff SHALL load branch; archive SHALL load finish.

#### Scenario: Start change work
- **WHEN** a new change is started
- **THEN** branch state MUST satisfy the branch contract before implementation

### Requirement: Project-private specialization
The shared workflow distribution SHALL contain only platform-neutral lifecycle contracts and adapters. Project-specific product, framework, domain, or maturity guidance SHALL remain in the owning downstream project.

#### Scenario: Deploy to an unrelated project
- **WHEN** the shared Codex workflow is installed in a downstream project
- **THEN** no guidance or skill private to another project SHALL be installed
