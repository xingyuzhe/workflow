## MODIFIED Requirements

### Requirement: Read-only Doctor and explicit repair
Artifact Doctor SHALL be read-only and SHALL compare the complete published skill against the source artifact, validate artifact metadata, require downstream neutral source to be absent, and check local OpenSpec schema and spec/design pairs. Text artifact hashing and comparison MUST treat LF and CRLF line endings as equivalent while detecting every other content difference.

#### Scenario: Generated file drift
- **WHEN** an adapter differs from canonical source
- **THEN** Doctor SHALL fail and leave the file unchanged

#### Scenario: Git converts artifact line endings
- **WHEN** source and published text artifacts differ only by LF versus CRLF line endings
- **THEN** Artifact Doctor MUST accept their content as equivalent

#### Scenario: Artifact text actually changes
- **WHEN** a published artifact differs from the source by content other than line endings
- **THEN** Artifact Doctor MUST report content drift and leave the file unchanged
