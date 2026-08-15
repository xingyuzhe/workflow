## MODIFIED Requirements

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
