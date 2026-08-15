# Module responsibility

`deploy-kit` owns deterministic construction, publication, migration cleanup, and integrity checking of the self-contained workflow runtime.

# Structure and interfaces

- Build copies neutral contracts and source CLI into `.agents/skills/workflow`.
- Publish copies that single runtime and installs `.workflow` project data/config/schema paths.
- Manifest validation covers the CLI, module, contracts, and metadata.
- Migration moves project changes/specs before removing old workflow-owned paths.

# Relationships

The source repository owns `.workflow/pack` and `.workflow/cli`; downstream repositories own `.workflow/changes`, `.workflow/specs`, and project configuration.
