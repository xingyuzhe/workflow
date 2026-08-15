# workflow-runtime 模块设计

## 职责
命令入口、唯一 router、分期 state，以及与 OpenSpec CLI 的编排契约；branch/finish 短 prompt。

## 文件结构
```
.cursor/
  rules/workflow-router.mdc          # 唯一 alwaysApply
  commands/opsx-*.md
.cursor/workflow/
  pack/prompts/*.md                  # 含 branch/finish/grill/apply/...
  pack/gates/{tdd,verify,debug}.md
  state.json                         # gitignore；M3 起维护
  version.json
  manifest.json
```

## 关键类型 / 接口
- Command → prompt 映射（router + command 文件）
- `state.json`：`active_change`, `phase`, `branch`, `updated_at`

## 与其它模块的关系
- 消费 `schema-pack`；apply 引用 `quality-gates`；可选 `design-review`
- 由 `deploy-kit` 安装；破坏性替换旧入口

## 本次变更的设计决策
- 见 change design D1、D3、D4、D7
