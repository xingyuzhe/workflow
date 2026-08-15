# schema-pack Specification

## Purpose

Provide the authoritative repository-local artifact contract and filesystem invariants for workflow changes.

## Requirements

### Requirement: Project-local artifact contract
The system SHALL ship the repository-owned `workflow-contract` schema under `.workflow/schemas/workflow-contract/`. It SHALL define artifact dependencies, ownership, templates, and parser-sensitive validation without depending on an external schema registry or package.

#### Scenario: Load artifact instructions
- **WHEN** the local CLI receives `instructions <artifact> --change <name> --json`
- **THEN** it MUST resolve schema metadata and templates from the repository-local workflow directory

### Requirement: Complete capability pairs
Every capability under change or main specs SHALL contain both `spec.md` and `design.md`. Validation, sync, and archive MUST reject incomplete pairs.

#### Scenario: Missing companion design
- **WHEN** a capability contains `spec.md` without `design.md`
- **THEN** local validation MUST fail with the missing companion path

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
Sync and archive SHALL create or update main `.workflow/specs/<capability>/design.md` alongside `spec.md`. Publishing a capability with only one file SHALL NOT be allowed.

#### Scenario: Sync new capability
- **WHEN** a change introduces capability `foo` and sync runs
- **THEN** main `.workflow/specs/foo/spec.md` and `design.md` MUST both exist afterward
