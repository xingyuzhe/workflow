# schema-pack Specification

## Purpose
TBD - created by archiving change workflow-v2. Update Purpose after archive.
## Requirements
### Requirement: Custom schema workflow-spec
The system SHALL ship a project-local OpenSpec schema named `workflow-spec` at `openspec/schemas/workflow-spec/`. New changes under v2 defaults SHALL use `workflow-spec`. The schema SHALL be a shallow fork of `spec-driven` (renamed; templates/instructions document spec+design pairing and SSOT). The schema SHALL NOT rely on OpenSpec CLI filesystem enforcement for companion `design.md` files.

#### Scenario: Default new change
- **WHEN** a user starts a new change with v2 defaults
- **THEN** the change MUST use schema `workflow-spec`

#### Scenario: Schema resolution
- **WHEN** `openspec schema which workflow-spec` runs in a deployed project
- **THEN** it MUST resolve from project-local `openspec/schemas/workflow-spec`

### Requirement: Per-capability spec and design pair
For every capability under `specs/<capability>/`, the agent SHALL create both `spec.md` and `design.md` in the same step. A capability directory containing only `spec.md` SHALL be considered incomplete. Enforcement is via prompts and `openspec/config.yaml` rules, not CLI structural validation.

#### Scenario: Specs artifact creation
- **WHEN** the specs artifact is produced for capabilities A and B
- **THEN** both `specs/A/{spec.md,design.md}` and `specs/B/{spec.md,design.md}` MUST exist before specs is marked complete

### Requirement: SSOT anti-duplication
Proposal owns why/scope; change-level design owns cross-cutting decisions; per-capability design owns module internals; per-capability spec owns verifiable behaviors. Duplicating the same multi-line structural or type content across two artifacts SHALL be forbidden; non-authoritative artifacts MUST link instead.

#### Scenario: Module file tree placement
- **WHEN** documenting a module's file tree
- **THEN** it MUST appear in `specs/<capability>/design.md` and MUST NOT be fully copied into proposal or change-level design

### Requirement: Sync keeps pairs
Agent-driven sync SHALL create or update `openspec/specs/<capability>/design.md` alongside `spec.md`. Creating a new main capability with only `spec.md` SHALL NOT be allowed.

#### Scenario: Sync new capability
- **WHEN** a change introduces capability `foo` and sync runs
- **THEN** main `openspec/specs/foo/spec.md` and `design.md` MUST both exist afterward

