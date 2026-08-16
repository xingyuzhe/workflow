# Verification

## Result

PASS. The implementation, change artifacts, generated Codex runtime, and documented deployment boundary are coherent. No accepted residual is recorded.

## Requirement evidence

| Requirement | Result | Evidence |
|---|---|---|
| Deterministic migration report | PASS | `scripts/tests/WorkflowDeploy.Tests.ps1` verifies sorted unique action arrays, first-run classification, empty repeat actions, `deploy.ps1 -Json`, version `6.2.0`, and Doctor validity. |
| Artifact-only downstream publication | PASS | The realistic legacy fixture migrates root design, active/archive changes, and accepted spec/design pairs; it removes source-only runtime layout and passes both Doctors. |
| Read-only Doctor and explicit repair | PASS | Local and Artifact Doctor report the exact injected `.workflow/changes/doctor-residue/.openspec.yaml` path; a full-tree fingerprint proves diagnosis made no write. Existing drift and line-ending tests also pass. |
| Remove superseded namespaces | PASS | The fixture removes the old Codex skill, `.cursor/workflow`, fixed opsx command, legacy-marker router, and all legacy change metadata while preserving project data. |
| Failure-safe target mutation | PASS | Root-design and invalid-shape fixtures fail preflight with byte-identical targets. The `after-legacy-cleanup` failpoint restores migrated project data and bounded Cursor candidates byte-for-byte. |
| Explicit workflow ownership | PASS | Current `/workflow:*` adapter, private commands, rules, skills, Cursor MCP, neutral rule/MCP inputs, and AGENTS content outside the managed block remain intact. |
| Local artifact integrity diagnosis | PASS | Published local Doctor succeeds with an empty PATH, rejects manifested drift and unmanifested files, rejects legacy residue, and requires no external lifecycle package. |

## Checks

- `pwsh -NoProfile -File scripts/build.ps1` — PASS; repeat build produced identical generated-artifact hashes.
- `pwsh -NoProfile -File scripts/tests/WorkflowDeploy.Tests.ps1` — PASS.
- `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/tests/WorkflowDeploy.Tests.ps1` — PASS.
- `pwsh -NoProfile -File scripts/doctor.ps1 -ProjectRoot .` — PASS.
- `.agents/skills/workflow/bin/workflow.ps1 doctor --json -ProjectRoot .` — PASS.
- `.agents/skills/workflow/bin/workflow.ps1 validate convergent-downstream-migration --json -ProjectRoot .` — PASS.
- `git diff --check` — PASS; only Git line-ending conversion notices were emitted.
