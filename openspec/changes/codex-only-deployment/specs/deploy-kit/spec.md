# deploy-kit Delta Specification

## ADDED Requirements

### Requirement: Client-scoped deployment

Init SHALL accept an explicit set of clients. It SHALL generate, clean, repair, and validate only the selected client adapters while continuing to install the neutral shared core.

#### Scenario: Codex-only deployment

- **WHEN** init runs with `-Clients codex`
- **THEN** Codex assets SHALL be generated and the `.cursor` tree SHALL remain byte-for-byte unchanged

### Requirement: Persistent installation scope

Deployment metadata SHALL record the installed client set. Repair and Doctor SHALL use that set when no explicit client set is provided.

#### Scenario: Repair Codex-only installation

- **WHEN** repair runs without a client argument after a Codex-only install
- **THEN** it SHALL repair Codex assets without adopting Cursor assets

## MODIFIED Requirements

### Requirement: Generate client adapters from neutral source

Init SHALL copy the workflow-owned `.workflow/pack`, preserve project-owned `.workflow/mcp.json`, `.workflow/rules.json`, and `.workflow/rules/`, then generate only the selected client runtime assets. Client adapter files SHALL NOT be used as source input.

#### Scenario: Default project init

- **WHEN** init runs with `-Yes` and no client selection
- **THEN** both clients SHALL receive deterministic adapters generated from `.workflow`
