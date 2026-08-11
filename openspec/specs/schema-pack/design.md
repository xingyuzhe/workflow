# schema-pack Design

## Responsibility

Provide the authoritative artifact graph, parser-sensitive content contract, and deterministic pair validation.

## Structure

```text
openspec/schemas/workflow-spec/schema.yaml
openspec/schemas/workflow-spec/templates/
openspec/config.workflow.yaml
openspec/config.project.yaml
openspec/config.yaml
scripts/doctor.ps1
```

## Interfaces

- OpenSpec reads schema dependencies and instructions.
- `config.workflow.yaml` selects the workflow schema.
- `config.project.yaml` owns project-private rules; generated `config.yaml` merges configuration.
- Doctor checks filesystem invariants that the schema graph cannot express.
- Prompts reference artifact readiness and do not duplicate schema instructions.

## Relationships

- `workflow-runtime` routes operations.
- `quality-gates` decides when produced work may be claimed complete.
- Deploy-kit installs the schema and config source files.
