# AI Dev Team 项目 - 完整对话总结

> 基于 OpenClaw 构建 4-Agent 自动化开发团队的方案设计与落地计划  
> 整理日期: 2026-02-26

---

## 一、项目目标

在一台 VPS 上部署 4 个独立 OpenClaw 进程（PM、Engineer、Tester、DevOps），挂载到企业 Slack，通过 GitHub Issue + Milestone 管理任务。人类在 Slack 说需求，系统自动完成从拆分、编码、测试到部署的全流程。目标一周内跑通原型。

## 二、核心架构决策

### 已确定的方案

1. **4 个独立 OpenClaw 进程**（port 18789-18792），不使用 OpenClaw 内置的 multi-agent routing / sessions_send / Lobster 工作流引擎
2. **完全模拟人类协作**：Agent 之间只通过 Slack 消息和 GitHub Issue 交流，不通过内存通信
3. **GitHub Issue Label 做状态机**（确定性编排），Slack @mention 做即时通知（辅助）
4. **4 个独立 Slack App/Bot** 加入同一个 `#ai-dev-team` channel，`requireMention: true`
5. **Heartbeat 定时轮询 + Slack @mention 即时触发**并存的双保险机制
6. **Engineer 使用 Codex CLI (OpenAI API) 做实际编码**，OpenClaw (GLM-5) 做需求理解和调度
7. **每个 agent 独立 clone 一份项目 repo**，避免 git 操作冲突
8. **初期 Demo 选纯后端 API 任务**，不做前端 UI 和 Playwright E2E 测试，Tester 只用 vitest + curl
9. **项目初始化由人工完成**（create-next-app + Supabase 配置），给 agent 一个已经能跑的项目
10. **Slack historyLimit 设为 10**，避免 channel 消息膨胀撑爆上下文

### 技术选型

| 组件 | 选型 |
|------|------|
| Agent 框架 | OpenClaw (latest)，4 个独立进程 |
| Agent LLM | GLM-5（推理和协调） |
| 编码引擎 | Codex CLI + OpenAI API（Engineer 专用） |
| 沟通渠道 | Slack Socket Mode，4 个 Slack App |
| 任务管理 | GitHub Issues + Milestones + Labels |
| 目标项目 | Next.js (App Router) + Supabase + TypeScript |
| 测试框架 | vitest（单元测试）+ curl（API 集成测试） |
| 部署平台 | Vercel（GitHub Integration 自动部署） |
| 数据库 | Supabase (PostgreSQL) |

### 当前环境

- VPS 已有，Node 22+ 已装好
- GitHub repo 新建空 repo
- Slack 用个人测试 workspace 先跑通
- GLM-5 API key 自行配置
- Codex CLI 使用 OpenAI API key

## 三、GitHub 任务状态机

Label 驱动的状态流转：

```
人类需求 → [status/planning] → PM 拆分
  → [status/ready-for-dev] → Engineer 领取
  → [status/in-progress] → Engineer 开发（Codex CLI 编码 + pnpm test）
  → [status/ready-for-test] → Tester 验证
  → [status/testing] → Tester 工作
    → 通过: [status/ready-for-deploy] → DevOps 部署
    → 失败: [status/test-failed] → Engineer 修复（最多 3 次，超过标 blocked 通知人类）
  → [status/deploying] → DevOps 部署
  → [status/done] → 完成关闭
```

## 四、4 个角色定义

### PM Agent
- 职责：需求理解、Issue 拆分、优先级管理、进度监控
- 触发：Slack @mention + Heartbeat (30min)
- 特殊职责：新成员入职时逐个 @mention 通知团队；检查停滞超 60 分钟的 Issue

### Engineer Agent
- 职责：读 Issue → 构造 Codex CLI prompt → 检查输出 → commit/push/PR
- 触发：Slack @mention + Heartbeat (15min)
- 编码流程：调用 `codex --approval-mode full-auto "<prompt>"`，prompt 包含 AC 和"完成后跑 pnpm test"
- 修复 test-failed 最多 3 次，超过求助人类

### Tester Agent
- 职责：独立环境验证（checkout PR branch → pnpm test → curl API → 写测试报告）
- 触发：Slack @mention + Heartbeat (15min)
- 初期策略：只做 vitest 单元测试 + curl API 测试，不做浏览器 E2E

### DevOps Agent
- 职责：merge PR (--squash) → 等 Vercel 自动部署 → health check → Slack 通知
- 触发：Slack @mention + Heartbeat (30min)

## 五、并发与消息处理

- OpenClaw 每个 session 同一时间只有 1 个 active run
- Agent 正在执行长任务时，新 @mention 进入 queue（collect 模式），等当前任务完成后处理
- Heartbeat 跑在独立的 cron lane，不被 inbound 消息阻塞
- Bot A @mention Bot B 会通过 Slack app_mention event 触发 Bot B
- `@channel` / `@here` / `@all` 对 bot 无效，不会触发 app_mention event

## 六、团队成员发现机制

不使用静态配置文件，采用"入职仪式"模式：
- 新 bot 上线后 @mention PM 自我介绍
- PM 记录后逐个 @mention 其他成员通知（每次只 @mention 1 人）
- 每个 agent 将团队成员信息写入自己的 MEMORY.md 持久化
- 不依赖 Slack history（historyLimit 只有 10 条，早期消息会被截断）

## 七、关键风险与缓解

| 风险 | 缓解 |
|------|------|
| Playwright/E2E 环境问题 | 初期不做，只用 vitest + curl |
| Engineer 修 bug 死循环 | 3 次上限，超过 blocked + 通知人类 |
| 4 进程共用 git 目录冲突 | 每 agent 独立 clone repo |
| 项目上下文过大 | 控制在 10 个文件以内，每 Issue 改 1-2 个文件 |
| GLM-5 API 超时 | 配 fallback model；失败时 Slack 报错 |
| Tester dev server 阻塞 shell | 后台启动或用 vitest 直接测 handler |
| Issue 状态停滞 | PM heartbeat 检查 >60min 停滞 |
| Slack 消息撑爆上下文 | historyLimit: 10 |
| 消息风暴 / 循环 @mention | AGENTS.md 规定每次回复最多 @mention 1 人 |

## 八、7 天执行计划

| Day | 目标 | 验证标准 |
|-----|------|---------|
| 1 | 单 Agent 跑通：PM 连 Slack + GitHub | @PM Bot 能对话、能创建 Issue |
| 2 | 4 个进程全部跑通 + Slack 联调 | 4 bot 响应 @mention，bot 间能互相触发 |
| 3 | 项目初始化 + AGENTS.md 编写 | Next.js 项目能跑，4 份角色定义完成 |
| 4 | PM → Engineer 半链路 | Issue 创建 → Codex 编码 → PR 出现 |
| 5 | Tester → DevOps 半链路 | 测试报告 → merge → Vercel 部署 |
| 6 | 全链路联调（/api/health） | Slack 一句话到 Vercel 上线，全程无人工 |
| 7 | 第二个真实任务（CRUD API）+ 加固 | Supabase 接入 + 异常流程验证 |

## 九、Demo 选题路线

1. `GET /api/health` → 最小闭环（1 个文件，curl 验证）
2. `POST /api/users` + `GET /api/users/:id` → 引入 Supabase
3. Input validation (zod) → 增加业务逻辑
4. `GET /api/orders?userId=xxx` → 多表查询

## 十、进程部署布局

```
/home/
├── agent-pm/       (port 18789, GLM-5)
│   ├── .openclaw/workspace/   # AGENTS.md, SOUL.md, HEARTBEAT.md...
│   └── project/               # repo 副本（只读参考）
├── agent-eng/      (port 18790, GLM-5 + Codex CLI/OpenAI)
│   ├── .openclaw/workspace/
│   └── project/               # repo 副本（读写编码）
├── agent-test/     (port 18791, GLM-5)
│   ├── .openclaw/workspace/
│   └── project/               # repo 副本（读写测试）
└── agent-devops/   (port 18792, GLM-5)
    ├── .openclaw/workspace/
    └── project/               # repo 副本（merge + deploy）
```

## 十一、OpenClaw 配置要点

每个进程的 openclaw.json 核心差异：

| 配置项 | PM | Engineer | Tester | DevOps |
|--------|-----|----------|--------|--------|
| port | 18789 | 18790 | 18791 | 18792 |
| heartbeat.every | 30m | 15m | 15m | 30m |
| tools.allow | exec,read,message | exec,read,write,edit,message | exec,read,message | exec,read,message |

通用配置：
- `channels.slack.historyLimit: 10`
- `channels.slack.channels.#ai-dev-team.requireMention: true`
- `messages.queue.mode: "collect"`
- Heartbeat 用便宜模型降低成本

---
