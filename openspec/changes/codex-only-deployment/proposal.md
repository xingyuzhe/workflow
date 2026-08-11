# Change: Add client-scoped workflow deployment

## Why

Projects may adopt the Codex adapter without adopting or changing Cursor assets. The current installer always generates, cleans, and validates both clients, so a Codex deployment can unintentionally modify project-owned Cursor content.

## What Changes

- Add explicit client selection to init, repair, metadata, and Doctor.
- Make Codex-only deployment leave the entire `.cursor` tree outside its ownership boundary.
- Keep shared workflow source platform-neutral and keep project-specific rules and skills in their owning downstream projects.
- Preserve the existing two-client default for callers that intentionally deploy both adapters.

## Impact

- Workflow version advances to 3.2.0.
- Downstream Codex deployments use `init.ps1 -Clients codex -Yes`.
- Installed metadata becomes the authority used by repair and Doctor to retain client scope.
