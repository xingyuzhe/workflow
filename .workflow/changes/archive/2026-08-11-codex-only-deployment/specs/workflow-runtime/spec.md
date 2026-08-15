# workflow-runtime Delta Specification

## ADDED Requirements

### Requirement: Project-private specialization

The shared workflow distribution SHALL contain only platform-neutral lifecycle contracts and adapters. Project-specific product, framework, domain, or maturity guidance SHALL remain in the owning downstream project.

#### Scenario: Deploy to an unrelated project

- **WHEN** the shared Codex workflow is installed in a downstream project
- **THEN** no guidance or skill private to another project SHALL be installed
