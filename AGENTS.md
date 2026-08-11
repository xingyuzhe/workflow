# Repository guidance

<!-- BEGIN WORKFLOW MANAGED -->
## OpenSpec workflow

Use `$openspec-workflow` for explicit OpenSpec lifecycle work. Treat `/opsx:name`, `/opsx-name`, `$openspec-workflow name`, and equivalent lifecycle intent as aliases.

Route operations as follows: `explore`, `new`, `ff`, `continue`, `grill`, `apply`, `verify`, `sync`, `archive`, and `doctor`. Failures remain in this workflow only when they occur within an active lifecycle operation.

- Treat `openspec/config.yaml` as generated from `openspec/config.workflow.yaml` and `openspec/config.project.yaml`; do not hand-edit it.
- Reconcile `.workflow/state.json` with `openspec status`; CLI output wins and missing local state never blocks work.
- Preserve unrelated user changes. Do not merge, push, open a PR, discard a branch, or archive without the authorization required by the workflow.
<!-- END WORKFLOW MANAGED -->
