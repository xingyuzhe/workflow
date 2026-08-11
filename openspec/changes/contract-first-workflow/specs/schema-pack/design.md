# schema-pack delta design

## Responsibility

Provide the authoritative artifact graph and parser-sensitive content contract.

## Structure

```text
openspec/schemas/workflow-spec/schema.yaml
openspec/schemas/workflow-spec/templates/
openspec/config.workflow.yaml
scripts/doctor.ps1
```

## Interfaces

- OpenSpec reads schema dependencies and instructions.
- Doctor checks filesystem invariants that the schema graph cannot express.
- Prompts reference artifact readiness and do not duplicate schema instructions.

## Relationships

- `workflow-runtime` routes operations.
- `quality-gates` decides when produced work may be claimed complete.
