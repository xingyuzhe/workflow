# workflow-cli Delta

## MODIFIED Requirements

### Requirement: Local artifact integrity doctor
Doctor SHALL verify published artifact metadata, the complete manifest file set, portable content hashes, and absence of supported legacy workflow residue without using an external source repository. Legacy residue SHALL include the old project-data root, old Codex skill, `.openspec.yaml` below `.workflow/changes`, the exact former Cursor workflow namespace, fixed opsx commands, and an old-marker router. Doctor MUST preserve unrelated and current Cursor content.

#### Scenario: Published contract drifts
- **WHEN** a manifested runtime file changes
- **THEN** local Doctor MUST report the exact drift and return unhealthy

#### Scenario: Legacy metadata remains
- **WHEN** an active or archived change contains `.openspec.yaml`
- **THEN** local Doctor MUST report the repository-relative metadata path and leave it unchanged

#### Scenario: Legacy Cursor runtime remains
- **WHEN** the repository contains the former `.cursor/workflow` namespace or a fixed opsx command
- **THEN** local Doctor MUST report the exact residue

#### Scenario: Current Cursor adapter remains
- **WHEN** the repository contains current `/workflow:*` commands or a router without legacy markers
- **THEN** local Doctor MUST NOT report those files as legacy residue
