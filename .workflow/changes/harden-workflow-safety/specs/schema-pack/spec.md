## ADDED Requirements

### Requirement: Explicit artifact roles
Every schema artifact SHALL declare a supported `kind`. Capability delta artifacts MUST also declare a safe repository-relative `publishPath`. Runtime behavior MUST NOT depend on conventional artifact IDs.

#### Scenario: Load a schema
- **WHEN** the CLI reads artifact metadata
- **THEN** it MUST reject unknown kinds, missing capability publication targets, unsafe paths, duplicate IDs, and unknown dependencies

### Requirement: Strict schema selection
Every Doctor and lifecycle command SHALL resolve the schema selected by generated project configuration and validate that exact local schema rather than assuming `workflow-contract`.

#### Scenario: Selected schema is missing
- **WHEN** project configuration selects a schema absent from the repository
- **THEN** every Doctor entry point MUST report the installation unhealthy
