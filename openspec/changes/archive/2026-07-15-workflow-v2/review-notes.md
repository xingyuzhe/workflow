# Review notes: workflow-v2

**Date:** 2026-07-15
**Status:** shared-understanding

## Confirmed decisions
- Pack：`.cursor/workflow/pack/` 真同构
- Schema：`openspec/schemas/workflow-spec/` 浅 fork；配对靠 prompts+config
- 三硬门禁 + branch/finish/grill 短 prompt
- **Grill 路径（verify 后修订）：** `.cursor/workflow/pack/prompts/grill.md`
- 不考虑兼容：无 keep-v1；破坏性 purge；覆盖 config；doctor 遇残留失败；doctor 校验 project-local `schema which`；已删 `scripts/init.sh`
- PowerShell 一等；M1 硬切；state@M3；`v1-final` 仅考古

## Open questions
- （无）

## Risks
| Risk | Severity | Mitigation |
|------|----------|------------|
| 破坏性 init | high | BREAKING.md |
| doctor 依赖 openspec CLI | medium | PATH + nvm 回退路径 |

## Artifact updates needed
- [x] design-review spec → prompts/grill.md
- [x] 删除 init.sh
- [x] doctor schema which

## Alignment summary
verify 缺口已修；可 Finish / Archive。
