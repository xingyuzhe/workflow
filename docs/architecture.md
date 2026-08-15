# Workflow 架构

当前版本：`6.1.0`。Workflow 是完全自定义、自包含的生命周期系统，只规定规则、产物、验收和授权边界。

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
- `.workflow/config.json` 由 workflow 默认配置和项目配置合并生成。
- 本地 CLI 直接读取这些文件；没有外部命令、注册表或缓存拥有更高优先级。
- capability 的 `spec.md` 与 `design.md` 必须成对。

## 生命周期事务

`sync` 与 `archive` 是单写者、可恢复的仓库本地事务。CLI 在首次修改目标前取得 `.workflow/.mutation.lock`，把原始值、prepared 值和严格 journal 写入 `.workflow/.transactions/<guid>/`，再依次经历 `prepared`、`committing`、`committed`。

- `sync` 以 capability 目录为原子 target，并把全部 capability 与 change receipt 放在同一事务中。目录级 prepared 副本保留 capability 内的项目自有文件。
- `archive` 在同一事务中发布 capability、创建带 receipt 的归档目录并删除活动 change。
- 捕获到的提交失败立即恢复所有原始 target；进程中断由下一个 `sync` 或 `archive` 在规划新写入前恢复。
- 恢复丢弃 `prepared`、回滚 `committing`、保留 `committed` 的目标状态并清理残留。
- `doctor` 只读报告 lock 或 transaction 残留，不取得锁，也不执行恢复。

journal 使用仓库相对路径并拒绝根路径、目录穿越、target 重叠、未知字段和 reparse point。运行时事务状态不是 change/spec 的事实来源。

## 客户端适配

Cursor 获得 `/workflow:*` 命令与 router；Codex 获得 `$workflow` skill、AGENTS managed block 和 references。适配文件均从相同契约生成，互不作为输入。

操作契约仅定义前置条件、输入、输出、验收、停止条件与 authority。共享 acceptance contract 要求完成声明有与风险相称的证据，但不固定 TDD、调试顺序、测试频率或重试次数。项目确有方法约束时，由项目规则限定范围。

## 构建、发布与 Doctor

`scripts/build.ps1` 从真相源重建 `.agents/skills/workflow`。

- `scripts/deploy.ps1` 是标准 Codex 下游发布：复制构建后的 skill，并安装项目使用的 `.workflow` 配置与 schema。源码专用的 `.workflow/pack`、`.workflow/cli`、默认规则、MCP 输入和部署脚本不发布。
- `scripts/init.ps1` 是完整 Cursor+Codex 安装：复制源码布局、部署脚本和两个客户端适配器，适合工作流源码仓库或确实需要 Cursor 的项目。

两种模式都必须保留项目已有 changes、specs、私有配置、项目规则、项目 MCP 配置和其他 skills。

源码 Doctor 检查源与生成物一致性。发布态 CLI 的 `doctor` 检查本地 schema、spec/design 配对、旧命名空间、本地 CLI 完整性与生命周期事务残留。两者都不通过下载依赖来“修复”环境。

配置归属：

| 文件 | 归属 | 更新方式 |
|---|---|---|
| `.workflow/config.workflow.json` | Workflow | 安装可更新 |
| `.workflow/config.project.json` | 项目 | 安装不覆盖 |
| `.workflow/config.json` | 生成物 | 安装或显式配置同步 |
