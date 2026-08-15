# quality-gates 模块设计

## 职责
apply 阶段三条硬门禁：TDD、完成前验证、系统化调试。

## 文件结构
```
.cursor/workflow/pack/gates/
  tdd.md
  verify.md
  debug.md
```

## 关键类型 / 接口
- 无独立命令；由 `pack/prompts/apply.md` 强制引用

## 与其它模块的关系
- 被 workflow-runtime apply 路径引用

## 本次变更的设计决策
- 见 change design D3；非技能框架、无 v1 skill 路径依赖
