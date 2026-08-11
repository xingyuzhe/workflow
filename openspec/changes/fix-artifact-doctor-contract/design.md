# Design: Fix artifact Doctor contract

The source repository exposes `scripts/check-deployment.ps1`, which calls the existing read-only Artifact Doctor with both source and target paths. The generated skill documents this publisher-owned interface. A downstream-only inspection may validate its signed-by-manifest file set but must report that source equivalence was not checked.
