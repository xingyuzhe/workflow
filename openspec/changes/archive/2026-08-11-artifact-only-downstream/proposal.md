# Change: Publish only the built Codex artifact downstream

## Why

The workflow repository is both the authoring source and a consumer of its generated Codex artifact. Downstream repositories are consumers only, so deploying the neutral `.workflow` source beside the generated `.agents` artifact creates an unnecessary second copy and an ambiguous ownership model.

## What Changes

- Keep `.workflow` as authoring truth only in the workflow repository.
- Build the self-contained Codex skill under `.agents/skills/openspec-workflow` for self-hosting and publication.
- Publish only the built Codex artifact and required OpenSpec integration outputs to downstream repositories.
- Store published version metadata inside the skill artifact.
- Remove previously deployed `.workflow`, generated rule indexes, and deployment-source scripts from downstream repositories.

## Impact

This is a breaking deployment-layout change. Downstream repositories no longer contain neutral workflow source or a local copy of the workflow deployment engine.
