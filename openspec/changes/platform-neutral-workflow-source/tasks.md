## 1. Contract and tests

- [x] 1.1 Add platform-neutral source, deploy-kit, and runtime specification/design pairs.
- [x] 1.2 Add failing tests for neutral MCP/rules generation, strict schema errors, single metadata/state, doctor drift, and explicit repair.

## 2. Neutral source and adapters

- [x] 2.1 Move packs and structured definitions to `.workflow` and update the skill/router/commands.
- [x] 2.2 Implement strict neutral MCP and rule readers plus Cursor/Codex generators.
- [x] 2.3 Replace duplicate metadata/state with `.workflow` authority.

## 3. Doctor and cleanup

- [x] 3.1 Make doctor read-only and content-aware; add `-Fix` repair.
- [x] 3.2 Remove superseded Cursor-source parsers, dual metadata/state, and stale documentation.

## 4. Verification and rollout

- [x] 4.1 Run deployment regression tests, skill validation, self-install, and strict doctor.
- [x] 4.2 Deploy and verify the generated workflow in bill and invoice-platform-edge.
