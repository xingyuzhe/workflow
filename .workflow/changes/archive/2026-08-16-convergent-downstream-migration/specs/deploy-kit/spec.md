# deploy-kit Delta

## ADDED Requirements

### Requirement: Deterministic migration report
Standard Codex publication SHALL produce a deterministic migration report with sorted repository-relative `migrated`, `removed`, `preserved`, and `blocked` path arrays. The report SHALL be evidence only and MUST NOT become lifecycle state. `deploy.ps1` SHALL expose the report as opt-in JSON together with artifact version and Doctor validity.

#### Scenario: Publication reports its migration
- **WHEN** a legacy downstream repository is published successfully with JSON output
- **THEN** every planned legacy action is classified and Doctor validity is included without absolute-path or runtime-order drift in the action arrays

#### Scenario: Publication is repeated
- **WHEN** publication runs again against the converged repository
- **THEN** the filesystem remains unchanged and no completed legacy action is reported as newly migrated or removed

## MODIFIED Requirements

### Requirement: Artifact-only downstream publication
Publish SHALL generate and copy exactly one Codex runtime at `.agents/skills/workflow`, including its local CLI, references, metadata, and manifest. It SHALL install project-owned `.workflow` configuration and schema data without publishing source-only pack or CLI directories as a second runtime. It SHALL migrate supported legacy project data, including a root design, before rejecting any remaining legacy namespace.

#### Scenario: Publish workflow artifact
- **WHEN** publish runs for a downstream repository containing supported legacy workflow data
- **THEN** `.agents/skills/workflow` SHALL be complete, project data SHALL be under `.workflow`, superseded workflow-owned runtime paths SHALL be absent, and no external package SHALL be required

#### Scenario: Legacy root design exists
- **WHEN** `openspec/design.md` exists and `.workflow/design.md` does not
- **THEN** publication SHALL preserve its content at `.workflow/design.md` and remove the obsolete root

#### Scenario: Root designs conflict
- **WHEN** both legacy and current root designs exist with different normalized content
- **THEN** publication MUST fail in preflight without changing the target

### Requirement: Read-only Doctor and explicit repair
Artifact Doctor SHALL be read-only and SHALL compare the complete published skill against the source artifact, validate metadata, reject source-only runtime directories downstream, reject supported legacy workflow residue, and invoke the published local Doctor to check selected schema, accepted specs, spec/design pairs, complete artifact integrity, and the same legacy residue. Text comparison MUST treat LF and CRLF as equivalent while detecting every other content difference. Repair requires an explicit build, deploy, or init operation outside Doctor.

#### Scenario: Generated file drift
- **WHEN** an adapter differs from canonical source
- **THEN** Doctor SHALL fail and leave the file unchanged

#### Scenario: Git converts artifact line endings
- **WHEN** source and published text artifacts differ only by line endings
- **THEN** Artifact Doctor MUST accept their content as equivalent

#### Scenario: Artifact text actually changes
- **WHEN** a published artifact differs by content other than line endings
- **THEN** Artifact Doctor MUST report drift and leave the file unchanged

#### Scenario: Legacy migration metadata remains
- **WHEN** `.workflow/changes` contains `.openspec.yaml`
- **THEN** Artifact Doctor MUST report the exact legacy metadata path and remain read-only

### Requirement: Remove superseded namespaces
The breaking migration SHALL remove exact workflow-owned superseded skills, command adapters, external CLI probes, old live configuration/schema paths, provenance-verified legacy deployment scripts, legacy change metadata, and the exact former Cursor workflow namespace after migrating project change, spec, and root-design data. It MUST preserve similarly named project content, current Cursor adapters, and unrelated Cursor content.

#### Scenario: Upgrade an existing repository
- **WHEN** standard Codex publication completes against a supported legacy installation
- **THEN** project data MUST exist only in the new workflow namespace and superseded workflow-owned Codex and Cursor runtime paths MUST be absent

#### Scenario: Remove legacy Cursor adapters selectively
- **WHEN** the target contains `.cursor/workflow`, fixed `opsx-<operation>.md` commands, an old-marker router, a private command, and current `/workflow:*` adapters
- **THEN** publication SHALL remove only the legacy namespace, opsx commands, and old-marker router

### Requirement: Failure-safe target mutation
Full installation and artifact-only publication SHALL validate all known source, configuration, schema, ownership, migration, root-design collision, and cleanup constraints before changing a target. If a caught mutation failure occurs after writes begin, the operation MUST restore every workflow-owned target path it changed, including bounded legacy Cursor candidates.

#### Scenario: Invalid target configuration
- **WHEN** installation receives an invalid project MCP, rule, configuration, selected schema definition, or conflicting root design
- **THEN** it MUST fail before deleting or writing any target content

#### Scenario: Mutation fails after preflight
- **WHEN** a filesystem mutation throws after target changes begin
- **THEN** the operation MUST restore the snapshotted workflow-owned target state before reporting failure

#### Scenario: Failure follows Cursor cleanup
- **WHEN** publication fails after removing a legacy Cursor candidate
- **THEN** that candidate and every earlier project-data mutation MUST be restored byte-for-byte

### Requirement: Explicit workflow ownership
Cleanup SHALL delete only exact legacy namespaces, exact current workflow namespaces, fixed legacy command paths, files recorded by a workflow-managed index, or a router whose content contains required legacy routing markers. It MUST NOT infer ownership solely from a generic `workflow-` name prefix, a loose source-code marker, or the existence of unrelated Cursor content.

#### Scenario: Project has a workflow-prefixed private skill
- **WHEN** the target contains `.cursor/skills/workflow-private`
- **THEN** install MUST preserve it byte-for-byte

#### Scenario: Downstream has project-owned neutral inputs
- **WHEN** artifact publication finds project `.workflow/rules.json`, `.workflow/rules/`, or `.workflow/mcp.json`
- **THEN** it MUST preserve and compile those inputs without replacing them with source-repository defaults

#### Scenario: Router is current or private
- **WHEN** `.cursor/rules/workflow-router.mdc` contains no former OpenSpec or opsx routing marker
- **THEN** standard Codex publication MUST preserve it byte-for-byte
