# Module responsibility

`deploy-kit` owns deterministic artifact construction, publication, and read-only integrity validation.

# Structure and interfaces

- A module-local content-hash helper canonicalizes CRLF and lone CR to LF before SHA-256 hashing.
- Manifest construction, manifest validation, and source-to-published comparison use the same helper.
- Artifact files remain ordinary UTF-8 text and no downstream runtime is introduced.

# Relationships

The neutral `.workflow` source remains authoritative. The generated `.agents/skills/openspec-workflow` artifact remains the only downstream workflow payload.
