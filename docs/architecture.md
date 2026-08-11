# Workflow 架构

当前版本：`3.1.0`。Workflow 面向 Cursor 与 Codex 提供同一套 OpenSpec 生命周期契约：规定输入、产物、验收、停止条件和授权边界，默认不规定 agent 的具体操作方法。

## 单一事实来源

`.workflow/` 是唯一平台无关源：

```text
.workflow/
├── pack/
│   ├── prompts/
│   └── gates/
├── mcp.json
├── rules.json
├── rules/
├── version.json
├── manifest.json
└── state.json       # 可选；OpenSpec CLI 状态仍优先
```

结构化源使用严格 JSON schema。规则正文使用 Markdown，并由 `rules.json` 提供 description、always 和 paths。未知字段、非法类型、路径逃逸和重复规则直接失败。

## 客户端适配

```text
.workflow SSOT
├── Cursor
│   ├── .cursor/commands/opsx-*.md
│   ├── .cursor/rules/**/*.mdc
│   └── .cursor/mcp.json
└── Codex
    ├── AGENTS.md managed block
    ├── .agents/skills/openspec-workflow/
    ├── .agents/rules/**/*.md
    └── .codex/config.toml managed block
```

客户端文件是生成物，不互相作为输入。规则生成器仅删除 `.workflow-managed.json` 明确记录的旧文件；`AGENTS.md` 和 Codex TOML 只更新 managed block，保留块外项目内容。

Codex skill 的 `SKILL.md` 只负责生命周期路由；详细操作契约从中立 pack 生成到 references，按操作渐进加载。普通 bug 与测试失败不由该 skill 捕获，除非发生在活跃生命周期操作内。

## MCP

`.workflow/mcp.json` 支持 `stdio` 与 `http` transport，并严格校验 transport 必需字段。适配器生成 Cursor JSON 和 Codex TOML；server 名、header 和环境变量 key 安全引用。密钥应通过环境变量引用，不写入源文件。

## Doctor 与修复

```powershell
pwsh -File scripts/doctor.ps1 -ProjectRoot path\to\project
pwsh -File scripts/doctor.ps1 -ProjectRoot path\to\project -Fix
```

默认 Doctor 只读，比较 canonical source 与规则、命令、MCP managed block、AGENTS managed block、skill references、metadata 和合并后的 OpenSpec config；同时检查 spec/design 配对及旧 skill 残留。

`-Fix` 显式调用生成器，再运行相同的严格检查。OpenSpec CLI 存在时额外验证 `workflow-spec` 解析到项目本地；不存在时只校验本地 schema 文件，不使用机器特定的版本路径。

## OpenSpec 配置

| 文件 | 归属 | 写入方式 |
|---|---|---|
| `openspec/config.workflow.yaml` | Workflow | init 可覆盖 |
| `openspec/config.project.yaml` | 项目 | init 不覆盖 |
| `openspec/config.yaml` | 生成物 | init、显式 sync 或 doctor `-Fix` |

默认 Doctor 不自动同步 `config.yaml`，因此陈旧合并结果会作为 drift 报告。

## 交付与验收契约

操作 prompt 只定义前置条件、输入、产物、验收、停止条件和授权边界。`.workflow/pack/gates/acceptance.md` 要求在完成任务或报告成功前提供与变更风险相称的证据。

Shared workflow 不规定 TDD、调试顺序、测试频率或重试次数。具体方法由 agent 结合项目规则、工具协议、active change artifacts 与任务风险选择；项目确有强约束时，应通过项目规则精确限定适用范围。

Doctor 负责检查 acceptance contract 存在，并拒绝已废弃的 `tdd.md`、`debug.md`、`verify.md` workflow gate。
