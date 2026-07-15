# deploy-kit 模块设计

## 职责
破坏性 `init` + `doctor`：安装 v2 真同构布局；无条件清除工作流旧栈；隔离并合并 openspec config；校验残留即失败。

## 文件结构
```
scripts/init.ps1
scripts/doctor.ps1
.cursor/workflow/{pack,version.json,manifest.json}
openspec/schemas/workflow-spec/
openspec/config.workflow.yaml   # init 可覆盖
openspec/config.project.yaml    # init 永不覆盖
openspec/config.yaml            # 合并产物（自动重生成）
```

## 关键类型 / 接口
- Flags：`-Yes`（非交互）；**无** keep-v1
- Doctor：非零 = 失败（含 v1 残留）；校验三配置文件存在且合并产物含 `schema:`
- Merge：`Merge-WorkflowOpenSpecConfig`（rules 按键拼接去重；标量 project 可覆盖）

## 与其它模块的关系
- 安装 runtime / gates / schema-pack / design-review 运行时文件
- 不删除业务 `openspec/specs`
- 不覆盖 `config.project.yaml`

## 本次变更的设计决策
- 见 change design D5、D7、D8、D9；配置隔离见主规格「Isolate and merge openspec config」
