# deploy-kit Design

## Responsibilities

- Build generated client artifacts from workflow-owned neutral source.
- Publish the self-contained Codex artifact without publishing neutral source.
- Preserve project-owned rules, unrelated skills, configuration surroundings, and business specs.
- Validate published artifacts against the source artifact.

## Interfaces

- `scripts/build.ps1`
- `scripts/deploy.ps1 -Target <path> -Yes`
- `Build-WorkflowCodexArtifact`, `Publish-WorkflowCodexArtifact`
- `Invoke-WorkflowArtifactDoctor`

## Safety

The workflow repository retains `.workflow` plus its generated `.agents` artifact. Downstream publication copies only the artifact namespace and required OpenSpec standard-path integration. Migration removes the previously published `.workflow`, empty generated-rule index, and deployment-engine scripts. Mixed-ownership files use bounded markers.
