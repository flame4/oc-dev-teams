# Message Directionality — 消息风暴治理

## 问题

PM 和 ENG 在 Slack channel 中产生消息风暴：
1. **确认连锁**：互相 @mention 说结论后，对方 @mention 回来说"收到"，然后又触发回复
2. **过度通知人类**：ENG 把人类当上帝，任何状态变更都要 @mention 人类汇报

根因：提示词没有区分"需要对方行动的消息"和"纯通知消息"，每条 @mention 都被当作需要回复的请求。

## 方案

引入 **Message Directionality** 原则 — 每条消息二分为 actionable 或 informational：

- **Actionable**：需要对方做事（回答问题、领任务、做决定）→ 用 @mention
- **Informational**：纯状态广播（PR 创建了、开始干活了、任务完成了）→ 不 @mention，或 @mention 但不期望回复

三条规则：
1. 只在需要对方**行动**时才 @mention
2. 收到 informational 消息用 emoji reaction（👀 ✅ 👍）代替文字回复
3. 永远不要确认别人的确认

补充 **Channel Awareness** 原则 — bot 在 heartbeat/触发时静默扫描近期 channel 消息，有用信息写入 MEMORY.md，不回复不确认。

## 改动

| 文件 | 改动 |
|------|------|
| `agent-eng/workspace/AGENTS.md` | +Message Directionality, +Channel Awareness; 精简 Escalating to Human (23→4行), Handling Human Comments (30→2行); Picking Up Issues step 7 标注 informational |
| `agent-pm/workspace/AGENTS.md` | +Message Directionality, +Channel Awareness; Team Member Self-Update 改为 emoji reaction |
| `agent-pm/workspace/HEARTBEAT.md` | 去掉"万事平安"通知，改为静默 HEARTBEAT_OK |

净效果：删除 ~50 行，新增 ~25 行。

## 可行性依据

- Emoji reaction：两个 bot 的 Slack App 已配置 `reactions:write` scope
- Channel Awareness：bot 订阅 `message.channels` 事件，`historyLimit: 10` 确保被触发时上下文包含近期消息，`requireMention: true` 保证不会为每条消息触发 agent run
