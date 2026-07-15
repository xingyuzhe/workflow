# design-review 模块设计

## 职责
grilling 压测设计；沉淀 `review-notes.md`。

## 文件结构
```
.cursor/workflow/pack/prompts/grill.md
openspec/changes/<name>/review-notes.md
```

## 关键类型 / 接口
- `/opsx:grill` 或意图加载 `pack/prompts/grill.md`
- review-notes 为辅助记录，非主 artifact

## 与其它模块的关系
- 读取 schema-pack 产出；位于 design 后、apply 前（可选，默认不硬阻断）

## 本次变更的设计决策
- 见 change design D6；路径统一为 `pack/prompts/grill.md`
