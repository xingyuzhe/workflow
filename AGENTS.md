# Repository guidance

<!-- BEGIN WORKFLOW MANAGED -->
## Workflow

Use `$workflow` for explicit workflow lifecycle work. Treat `/workflow:name`, `/workflow-name`, `$workflow name`, and equivalent lifecycle intent as aliases.

Route operations as follows: `explore`, `new`, `ff`, `continue`, `grill`, `apply`, `verify`, `sync`, `archive`, and `doctor`. Failures remain in this workflow only when they occur within an active lifecycle operation.

- Treat `.workflow/config.json` as generated from `.workflow/config.workflow.json` and `.workflow/config.project.json`; do not hand-edit it.
- Use `.agents/skills/workflow/bin/workflow.ps1` for lifecycle state and validation. Repository files are authoritative.
- Never install, download, discover, or invoke an external lifecycle CLI or package. A missing local CLI is an invalid workflow installation.
- Preserve unrelated user changes. Do not merge, push, open a PR, discard a branch, or archive without the authorization required by the workflow.
<!-- END WORKFLOW MANAGED -->
