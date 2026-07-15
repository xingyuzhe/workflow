# schema-pack 模块设计

## 职责
`workflow-spec` 浅 fork、SSOT/配对规则（模板 + config）、与 OpenSpec CLI 的路径契约。

## 文件结构
```
openspec/schemas/workflow-spec/   # SSOT；init 同步到目标同路径
openspec/config.workflow.yaml     # 工作流模板；init 可覆盖
openspec/config.project.yaml      # 项目私有；init 永不覆盖
openspec/config.yaml              # 合并产物（CLI 读取）
```

## 关键类型 / 接口
- Schema 名：`workflow-spec`
- 配对：规范约束（prompts/rules），非 CLI 硬校验

## 与其它模块的关系
- runtime / design-review 消费 artifacts
- deploy-kit 安装 schema 目录并合并 config

## 本次变更的设计决策
- 见 change design D2、D5（config 覆盖）、D9（不删业务 specs）
