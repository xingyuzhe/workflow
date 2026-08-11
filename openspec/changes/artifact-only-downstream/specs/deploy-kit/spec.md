# deploy-kit Delta Specification

## ADDED Requirements

### Requirement: Build before publication

The workflow repository SHALL generate a self-contained Codex artifact from the neutral source and SHALL use that same artifact for self-hosting and downstream publication.

#### Scenario: Build Codex artifact

- **WHEN** the neutral workflow contracts change
- **THEN** the generated skill references and artifact metadata SHALL be updated deterministically

### Requirement: Artifact-only downstream publication

Downstream publication SHALL copy the generated Codex artifact and required standard-path integration outputs. It SHALL NOT copy `.workflow` or the workflow deployment engine.

#### Scenario: Publish to downstream repository

- **WHEN** a Codex artifact is published
- **THEN** `.agents/skills/openspec-workflow` SHALL match the source artifact and `.workflow` SHALL be absent

### Requirement: Preserve project-owned agents content

Publication SHALL modify only its managed skill namespace and bounded integration outputs. It SHALL preserve project-owned rules and unrelated skills.

#### Scenario: Repository has private agents assets

- **WHEN** publication runs
- **THEN** private `.agents/rules` and unrelated `.agents/skills` SHALL remain unchanged

## REMOVED Requirements

### Requirement: Persistent installation scope

Downstream deployment no longer installs neutral-source metadata. Published artifact metadata replaces installation-scope metadata.
