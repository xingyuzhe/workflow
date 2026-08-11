# Change: Fix artifact Doctor contract

## Why

The published Doctor contract still referenced a downstream script removed by the artifact-only deployment model.

## What Changes

- Route strict read-only validation through a checker owned by the workflow source repository.
- Define local artifact-integrity inspection without claiming source equivalence.
- Explicitly prohibit recreating neutral source or deployment scripts downstream.
