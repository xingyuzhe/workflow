# Workflow 架构

当前版本：`5.0.0`。Workflow 是完全自定义、自包含的生命周期系统，只规定规则、产物、验收和授权边界。

## 两层结构

```text
源码仓库
.workflow/                         # 可编辑真相源、CLI 源码、schema、项目数据
└── build
    └── .agents/skills/workflow/   # Codex 生成运行时，供自身和下游使用

下游仓库
.agents/skills/workflow/           # 唯一运行时，含 bin/workflow.ps1
.workflow/                         # 项目 change/spec/config/schema 数据；不是第二份运行时
```

下游不包含源码专用的 `.workflow/pack` 和 `.workflow/cli`。skill 中的 references 与 bin 是已构建产物。

## 本地状态与契约

- `.workflow/changes/` 与 `.workflow/specs/` 是生命周期数据权威。
- `.workflow/schemas/workflow-contract/schema.json` 定义 artifact 图、依赖、路径和模板。
- `.workflow/config.yaml` 由 workflow 默认配置和项目配置合并生成。
- 本地 CLI 直接读取这些文件；没有外部命令、注册表或缓存拥有更高优先级。
- capability 的 `spec.md` 与 `design.md` 必须成对。

## 客户端适配

Cursor 获得 `/workflow:*` 命令与 router；Codex 获得 `$workflow` skill、AGENTS managed block 和 references。适配文件均从相同契约生成，互不作为输入。

操作契约仅定义前置条件、输入、输出、验收、停止条件与 authority。共享 acceptance contract 要求完成声明有与风险相称的证据，但不固定 TDD、调试顺序、测试频率或重试次数。项目确有方法约束时，由项目规则限定范围。

## 构建、发布与 Doctor

`scripts/build.ps1` 从真相源重建 `.agents/skills/workflow`。发布复制该 skill，并安装项目使用的 `.workflow` 配置与 schema；源码专用的 `.workflow/pack`、`.workflow/cli`、默认规则和 MCP 输入不发布。项目已有 changes、specs、私有配置、项目规则、项目 MCP 配置和其他 skills 均须保留。

源码 Doctor 检查源与生成物一致性。发布态 CLI 的 `doctor` 检查本地 schema、spec/design 配对、旧命名空间与本地 CLI 完整性。两者都不通过下载依赖来“修复”环境。

配置归属：

| 文件 | 归属 | 更新方式 |
|---|---|---|
| `.workflow/config.workflow.yaml` | Workflow | 安装可更新 |
| `.workflow/config.project.yaml` | 项目 | 安装不覆盖 |
| `.workflow/config.yaml` | 生成物 | 安装、显式 sync 或 repair |
