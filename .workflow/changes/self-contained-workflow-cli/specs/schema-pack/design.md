# Module responsibility

`schema-pack` owns the local artifact graph, templates, and syntax validation consumed by the repository-owned CLI.

# Structure and interfaces

```text
.workflow/schemas/workflow-contract/
├── schema.json
└── templates/
```

JSON holds machine-readable dependencies and template paths. Markdown templates remain human-readable and agent-editable.

# Relationships

`workflow-cli` is the only runtime consumer. No external schema registry participates.
