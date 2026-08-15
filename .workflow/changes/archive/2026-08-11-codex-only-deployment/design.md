# Design: Client-scoped workflow deployment

## Decisions

### Shared core and client adapters are separate ownership layers

Every installation still owns the neutral `.workflow` pack, OpenSpec schema/config composition, and deployment scripts. Cursor and Codex adapter generation is conditional on the selected client list.

### Unselected clients are completely out of scope

Codex-only installation does not inspect, generate, purge, repair, or validate `.cursor`. The same boundary applies symmetrically to Codex adapter paths during a Cursor-only installation.

### Installed metadata retains scope

`.workflow/version.json` records the installed clients. Doctor and repair use that list when the caller does not provide one, preventing a later repair from silently broadening ownership.

### Project specialization stays downstream

The shared rule source remains empty and platform-neutral. Product-, framework-, domain-, and maturity-specific guidance is maintained only in its owning downstream project.

## Verification

Automated tests fingerprint a pre-existing `.cursor` tree before and after Codex-only install and repair, and require an identical result. Doctor must pass while Cursor-private workflow-shaped content remains present.
