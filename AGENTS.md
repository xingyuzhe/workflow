# Repository guidance

<!-- BEGIN WORKFLOW MANAGED -->
## OpenSpec workflow

Use `$openspec-workflow` for OpenSpec lifecycle work. Treat `/opsx:name`, `/opsx-name`, `$openspec-workflow name`, and a clear natural-language lifecycle request as equivalent.

Route operations as follows: `explore`, `new`, `ff`, `continue`, `grill`, `apply`, `verify`, `sync`, `archive`, and `doctor`. Bugs, test failures, and unexpected behavior use the skill debug gate.

- Treat `openspec/config.yaml` as generated from `openspec/config.workflow.yaml` and `openspec/config.project.yaml`; do not hand-edit it.
- Reconcile `.agents/workflow/state.json` with `openspec status`; CLI output wins and missing local state never blocks work.
- Preserve unrelated user changes. Do not merge, push, open a PR, discard a branch, or archive without the authorization required by the workflow.
<!-- END WORKFLOW MANAGED -->
