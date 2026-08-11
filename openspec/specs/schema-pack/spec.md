# schema-pack Specification

## Purpose

Provide the authoritative project-local artifact contract and filesystem invariants for OpenSpec changes.

## Requirements

### Requirement: Custom schema workflow-spec
The system SHALL ship a project-local `workflow-spec` schema at `openspec/schemas/workflow-spec/`. The schema SHALL define artifact dependencies, ownership, required sections, and parser-sensitive formatting without tutorial-style reasoning or implementation instructions.

#### Scenario: Default new change
- **WHEN** a user starts a new change with workflow defaults
- **THEN** the change MUST use schema `workflow-spec`

#### Scenario: Schema resolution
- **WHEN** `openspec schema which workflow-spec` runs in a deployed project
- **THEN** it MUST resolve from project-local `openspec/schemas/workflow-spec`

#### Scenario: Schema instructions are loaded
- **WHEN** an agent requests instructions for an artifact
- **THEN** the response MUST identify required output and syntax without prescribing a generic authoring method

### Requirement: Per-capability spec and design pair
For every capability under `specs/<capability>/`, both `spec.md` and `design.md` SHALL exist before the specs artifact is accepted. This invariant SHALL be defined in the schema contract and enforced by Doctor rather than repeated in every operation prompt.

#### Scenario: Incomplete capability pair
- **WHEN** Doctor finds exactly one of `spec.md` or `design.md`
- **THEN** Doctor MUST fail with the missing companion path

### Requirement: Required change-level design
Change-level `design.md` SHALL be a required artifact because tasks depend on it. If no cross-cutting decision is needed, it SHALL explicitly record that fact rather than being omitted.

#### Scenario: Small change
- **WHEN** a change has no cross-cutting design decision
- **THEN** it MUST still contain a concise design artifact before tasks become ready

### Requirement: SSOT anti-duplication
Proposal SHALL own motivation and scope, change-level design SHALL own cross-cutting decisions, per-capability design SHALL own module internals, and per-capability spec SHALL own verifiable behavior. Other workflow content SHALL reference these ownership rules instead of duplicating them.

#### Scenario: Lifecycle prompt addresses specs
- **WHEN** a lifecycle operation produces or verifies specs
- **THEN** the prompt MUST reference the artifact contract rather than restating its detailed format

### Requirement: Sync keeps pairs
Sync and archive SHALL create or update main `openspec/specs/<capability>/design.md` alongside `spec.md`. Publishing a capability with only one file SHALL NOT be allowed.

#### Scenario: Sync new capability
- **WHEN** a change introduces capability `foo` and sync runs
- **THEN** main `openspec/specs/foo/spec.md` and `design.md` MUST both exist afterward
