# deploy-kit Delta

## MODIFIED Requirements

### Requirement: Preserve project-owned surroundings
Publish SHALL update only its named artifact namespace and marked managed blocks. It SHALL preserve `AGENTS.md` and `.codex/config.toml` content outside managed blocks and SHALL NOT broadly delete project-owned rules or unrelated skills. Managed AGENTS guidance SHALL include the project-rules section only when at least one concrete project rule is configured.

#### Scenario: Reinstall
- **WHEN** publish runs twice
- **THEN** exactly one managed block SHALL remain and project-owned surrounding content SHALL be unchanged

#### Scenario: Project has no rules
- **WHEN** publication generates AGENTS guidance without a project rule catalog
- **THEN** the managed block SHALL omit the project-rules heading and contain no empty rule section
