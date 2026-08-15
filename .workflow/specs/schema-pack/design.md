# Module responsibility

`schema-pack` owns explicit artifact semantics in addition to dependency and template metadata.

# Structure and interfaces

Schema artifacts declare `kind`; capability delta artifacts declare `publishPath`. Both paths are repository-relative and validated before use.

# Relationships

The CLI consumes roles uniformly across status, validation, sync, and archive. Deployment preserves project-owned schemas and validates the schema selected by project configuration.
