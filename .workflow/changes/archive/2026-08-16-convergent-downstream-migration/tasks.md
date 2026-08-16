## 1. Legacy inventory and project-data migration

- [x] 1.1 Add a deterministic, read-only legacy inventory with migrated, removed, preserved, and blocked repository-relative paths.
- [x] 1.2 Migrate an equivalent legacy root design to `.workflow/design.md`, reject conflicting root designs in preflight, and remove exact `.openspec.yaml` metadata below change trees.

## 2. Bounded Cursor cleanup and publication rollback

- [x] 2.1 Remove the exact former Cursor workflow namespace, fixed opsx commands, and only a router with legacy routing markers while preserving current/private Cursor assets.
- [x] 2.2 Extend publication snapshots and failpoint coverage so project-data and bounded Cursor cleanup roll back byte-for-byte after a caught failure.

## 3. Reporting and diagnosis

- [x] 3.1 Return the migration report from publication and add deterministic opt-in JSON plus concise human counts to `deploy.ps1`.
- [x] 3.2 Make Artifact Doctor and the published local Doctor report legacy metadata and legacy Cursor residue while remaining read-only.

## 4. Regression coverage and repository cleanup

- [x] 4.1 Add realistic synthetic upgrade fixtures covering root design, active/archive metadata, old runtimes, private assets, first-run convergence, and second-run idempotence.
- [x] 4.2 Add report, Doctor, preflight-collision, selective ownership, and post-cleanup rollback assertions.
- [x] 4.3 Remove the final source `.openspec.yaml` metadata file and update architecture, README, and breaking-boundary documentation where the deployment contract changed.

## 5. Verification

- [x] 5.1 Rebuild generated artifacts and pass source Doctor plus published local Doctor.
- [x] 5.2 Pass the full test suite under PowerShell 7 and Windows PowerShell 5.1 with no substantive generated diff.
- [x] 5.3 Validate the active change and record requirement-by-requirement verification evidence.
