# Design

## Context

PowerShell can bind a pipeline-produced empty value to an object-array parameter as a single null element. The renderer currently checks array count directly, so it emits the section heading and then has no concrete entry to render.

## Goals / Non-Goals

**Goals:** Normalize renderer input to concrete non-null entries and keep generated output deterministic.

**Non-Goals:** Change rule parsing, managed-block ownership, or downstream configuration.

## Decisions

Filter null entries once inside `Get-WorkflowAgentsBlock`, then use that normalized collection for both the section condition and rendering loop. Keeping normalization at the rendering boundary protects every caller.

## Risks / Trade-offs

The change is intentionally narrow. A malformed non-null rule still follows existing strict validation and is not silently discarded.
