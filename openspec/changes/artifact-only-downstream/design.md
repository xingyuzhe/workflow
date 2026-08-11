# Design: Artifact-only downstream publication

## Source repository

`.workflow/pack` is the editable truth. The build step generates `.agents/skills/openspec-workflow/references` and artifact metadata. The workflow repository keeps both trees so changes are exercised through the same Codex artifact that downstream consumers receive.

## Downstream repositories

Publication copies the complete generated skill directory. It also updates the standard OpenSpec schema/config integration and bounded AGENTS/Codex managed blocks. It does not copy `.workflow` or deployment-engine scripts.

Project-owned `.agents/rules` and unrelated skills remain outside the publisher's ownership. A previous empty generated-rule index is removed during migration.

## Validation

Artifact Doctor requires `.workflow` to be absent downstream, validates artifact metadata, and can compare every published skill file against the workflow source artifact.
