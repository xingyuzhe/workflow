## 1. Schema & pack scaffolding (M1)

- [x] 1.1 新增 `openspec/schemas/workflow-spec/`（浅 fork `spec-driven`：模板写配对与 SSOT）
- [x] 1.2 新增 `.cursor/workflow/pack/prompts/`（explore、new、continue、ff、apply、verify、sync、archive、grill、branch、finish）
- [x] 1.3 新增 `.cursor/workflow/pack/gates/{tdd,verify,debug}.md`
- [x] 1.4 新增唯一 alwaysApply `workflow-router.mdc`
- [x] 1.5 新增 `/opsx:*` commands → pack prompts
- [x] 1.6 工作流模板 `openspec/config.yaml`：`schema: workflow-spec` + SSOT/pair rules（CLI 可解析的 rules 格式）

## 2. Deploy kit (M1)

- [x] 2.1 实现 `scripts/init.ps1`：真同构同步 pack、schema、router、commands；覆盖 `openspec/config.yaml`
- [x] 2.2 无条件 purge 工作流命名空间 skills（`superpowers*`/`openspec*`/`grilling*`/`workflow*`）；删除并重装工作流入口（`opsx-*` 等）；**不实现** keep-v1 flag
- [x] 2.3 写 `version.json` + `manifest.json`；gitignore `state.json`
- [x] 2.4 实现 `scripts/doctor.ps1`：缺文件 / 版本不一致 / **残留 v1 skills → 失败**
- [x] 2.5 init 末尾跑 doctor；失败非零退出
- [x] 2.6 **M1 硬切 checklist**：打/确认 `v1-final` → 删除源仓 v1 skills 树 → 自举 doctor 通过；不留 legacy 参考树

## 3. Quality gates wiring (M2)

- [x] 3.1 `pack/prompts/apply.md` 强制引用三门禁；勾选 tasks 前须有证据
- [x] 3.2 门禁 MUST/SHALL；docs-only 豁免；TDD 灰区询问
- [x] 3.3 冒烟：逻辑任务 RED-GREEN；docs 跳过 TDD

## 4. Schema behaviors (M2)

- [x] 4.1 new/continue/ff 强制每个 capability `spec.md`+`design.md`
- [x] 4.2 sync/archive 保持主规格配对
- [x] 4.3 SSOT 归属说明写入模板/短文档（非双轨迁移手册）

## 5. Runtime state & review (M3)

- [x] 5.1 维护 `.cursor/workflow/state.json`；冲突以 CLI 为准
- [x] 5.2 grill 短 prompt + `review-notes.md`；默认不硬阻断 apply
- [x] 5.3 短 BREAKING 说明（破坏性 init / 覆盖 config）；`v1-final` 仅考古一句——**无**双轨迁移脚本

## 6. Verification (M4)

- [x] 6.1 确认默认路径无任何 Superpowers/OpenSpec skill 运行时依赖
- [x] 6.2 本仓库自举：`init.ps1` + doctor 通过
- [x] 6.3 业务项目直接破坏性 init + 走通 explore→archive；回修 prompts/gates
- [x] 6.4 更新 README / redesign 里程碑状态
