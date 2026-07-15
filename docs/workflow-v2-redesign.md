# Workflow v2 — 绿场重设计

> 分支：`change/workflow-v2`  
> OpenSpec change：`openspec/changes/workflow-v2/`  
> 状态：**M1–M4 已落地（实现完成，待 archive）**  
> 立场：**不与 v1 运行时兼容 / 无双轨**

---

## 1. 一句话定位

**v2 = OpenSpec 流程产品 + 三条质量门禁 + 极薄 Cursor 适配层。**  
不是技能操作系统；不是 v1 的温和补丁。

---

## 2. 相对 v1 的本质差异

| 维度 | v1 | v2 |
|------|----|----|
| 中心 | 双技能宇宙 | **schema + 命令 + pack** |
| 质量 | Superpowers skills | **gates 短文** |
| 目录 | 版本化 skills | **`.cursor/workflow/pack/` 真同构** |
| 部署 | 可保留旧树 | **破坏性替换；无 keep-v1** |
| 配置 | 合并/共存 | **覆盖 `openspec/config.yaml`** |
| 脚本 | bash | **PowerShell 一等** |
| 状态 | 对话记忆 | **M3 state；权威=CLI** |

---

## 3. 架构

```
/opsx:* + workflow-router.mdc
        → .cursor/workflow/pack/prompts|gates
        → OpenSpec CLI + openspec/schemas/workflow-spec
        → apply 强制 tdd/verify/debug
        → version.json / manifest.json / (M3) state.json
        → doctor.ps1
```

---

## 4. 仓库目标布局（源 = 部署）

```
workflow/
├── versions.lock
├── openspec/
│   ├── schemas/workflow-spec/     # 浅 fork SSOT
│   └── config.yaml                # 工作流模板（init 覆盖目标）
├── .cursor/
│   ├── workflow/
│   │   ├── pack/
│   │   │   ├── prompts/           # 含 branch/finish/grill/apply/...
│   │   │   └── gates/             # tdd verify debug
│   │   ├── version.json
│   │   └── manifest.json
│   ├── rules/workflow-router.mdc
│   └── commands/opsx-*.md
├── scripts/
│   ├── init.ps1
│   └── doctor.ps1
└── docs/workflow-v2-redesign.md
```

**明确不存在：** 版本化 skill 树、bootstrap 双权威、`--keep-v1-skills`、legacy 参考树、双轨迁移套件。

---

## 5. 运行时契约（摘要）

- 命令 → pack prompt；apply → 三门禁
- branch/finish = 短 prompt，非门禁
- state：M3 维护；此前可选读；权威 `openspec status`
- SSOT：proposal / change design / module design / spec（见 config + schema 模板）

---

## 6. 部署（破坏性）

`init.ps1 -Yes <project>`：

1. 无条件 purge 工作流命名空间 skills  
2. 删除并重装工作流入口（router / `opsx-*` 等）  
3. 同步 `.cursor/workflow/pack/`  
4. 同步 `openspec/schemas/workflow-spec/`  
5. **整文件覆盖** `openspec/config.yaml`  
6. 写 version/manifest；跑 doctor（残留 v1 → **失败**）  

**不删**业务 `openspec/specs/**`。

---

## 7. 从 v1 升级（非兼容迁移产品）

1. 可选：自行 git 备份  
2. 跑 `init.ps1 -Yes`（接受破坏性替换）  
3. 走通一次 explore→archive  

考古：tag `v1-final`。无逃生阀、无迁移脚本套件。

---

## 8. 非目标

- v1 共存 / keep-v1 / 双轨迁移工具  
- 重写 OpenSpec CLI；Superpowers 框架；默认 SDD  
- v2.0 Linux 一等脚本、overlay CI、GUI  

---

## 9. 里程碑

| 里程碑 | 内容 |
|--------|------|
| M0 | 规格 + grill + 不考虑兼容收紧 ✅ |
| M1 | schema + pack + router + commands + PS init/doctor；**源仓硬切** ✅ |
| M2 | 三门禁 + 配对/sync ✅ |
| M3 | state 维护 + BREAKING 短说明 ✅ |
| M4 | 破坏性 init 冒烟（临时目标项目 + 本仓自举）✅；真实业务仓 explore→archive 可由用户指定路径续跑 |

---

## 10. 已锁定决策（含 grill）

| # | 决策 | 取值 |
|---|------|------|
| 1 | Schema | `workflow-spec` 浅 fork @ `openspec/schemas/` |
| 2 | Pack | `.cursor/workflow/pack/` 真同构 |
| 3 | v1 | **无条件 purge**；无 keep-v1；doctor 遇残留失败 |
| 4 | Grill | **`pack/prompts/grill.md`** |
| 5 | Config | **整文件覆盖** |
| 6 | 脚本 | PowerShell 一等 |
| 7 | 切仓 | M1 末硬切；先 `v1-final` |
| 8 | State | M3 维护 |
| 9 | 分支/收尾 | 短 prompt，非门禁 |
| 10 | 兼容 | **不考虑**；无双轨迁移产品 |

---

## 11. 下一步

按 M1→M4 实现（`/opsx:apply` 或等价开干）。
