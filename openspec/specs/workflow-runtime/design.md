# workflow-runtime Design

```text
.workflow/pack
├── prompts/*.md
└── gates/{tdd,verify,debug}.md
        │
        ├── Cursor commands + router
        └── Codex skill references + AGENTS routing
```

The neutral pack contains no client-owned state path. Both adapters refer to `.workflow/state.json`. Codex keeps the skill body concise and progressively loads only the required operation and gates.
