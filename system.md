# AI Dev Team System Design Document

> 基于 OpenClaw 构建的 4-Agent 自动化开发团队  
> Version: 0.1 (Prototype)  
> Last Updated: 2026-02-26

---

## 1. 项目概述

### 1.1 目标

在一台 VPS 上部署 4 个独立的 OpenClaw 进程，分别扮演 PM、Engineer、Tester、DevOps 四个角色。通过企业 Slack 做沟通渠道、GitHub Issue + Milestone 做任务管理，实现"人类在 Slack 说一句需求 → 自动完成开发、测试、部署"的全流程闭环。

### 1.2 核心设计原则

- **完全模拟人类协作**：Agent 之间不使用 OpenClaw 内部通信机制（sessions_send 等），只通过 Slack 消息和 GitHub Issue 交流，与人类团队的工作方式完全一致
- **GitHub 作为唯一事实源**：所有任务状态以 GitHub Issue Label 为准，Slack 消息只是通知手段
- **独立进程隔离**：4 个 OpenClaw 各自独立运行，互不依赖，一个挂了不影响其他
- **双保险触发机制**：Heartbeat 定时轮询 + Slack @mention 即时触发并存
- **渐进式复杂度**：初期 Demo 选择纯后端 API 任务，避免前端和浏览器测试的环境问题

### 1.3 技术选型

| 组件 | 选型 | 说明 |
|------|------|------|
| Agent 框架 | OpenClaw (latest) | 4 个独立进程，不同端口 |
| Agent LLM | GLM-5 | OpenClaw 的推理和协调用 |
| 编码引擎 | Codex CLI + OpenAI API | Engineer 专用，实际写代码 |
| 沟通渠道 | Slack (Socket Mode) | 4 个独立 Slack App |
| 任务管理 | GitHub Issues + Milestones | Label 驱动的状态机 |
| 目标项目 | Next.js + Supabase | 全栈项目 |
| 部署平台 | Vercel | GitHub Integration 自动部署 |
| 数据库 | Supabase (PostgreSQL) | 托管服务，免运维 |

---

## 2. 系统架构

### 2.1 总体架构

```
┌─────────────────────────────────────────────────────┐
│                    VPS (单台服务器)                    │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐                 │
│  │ OpenClaw:PM  │  │ OpenClaw:Eng │                 │
│  │  port:18789  │  │  port:18790  │                 │
│  │  GLM-5       │  │  GLM-5       │                 │
│  │              │  │  + Codex CLI  │                 │
│  └──────┬───────┘  └──────┬───────┘                 │
│         │                 │                          │
│  ┌──────┴───────┐  ┌──────┴───────┐                 │
│  │ OpenClaw:Test│  │ OpenClaw:Ops │                 │
│  │  port:18791  │  │  port:18792  │                 │
│  │  GLM-5       │  │  GLM-5       │                 │
│  └──────┬───────┘  └──────┬───────┘                 │
│         │                 │                          │
│         └────────┬────────┘                          │
│                  │                                   │
└──────────────────┼───────────────────────────────────┘
                   │
          ┌────────┴────────┐
          │                 │
    ┌─────▼─────┐    ┌─────▼─────┐
    │   Slack   │    │  GitHub   │
    │ (1 channel│    │ (Issues + │
    │  4 bots)  │    │  PRs)     │
    └───────────┘    └───────────┘
```

### 2.2 进程隔离布局

```
/home/
├── agent-pm/
│   ├── .openclaw/           # OpenClaw 配置和状态
│   │   ├── openclaw.json    # Gateway 配置 (port 18789)
│   │   ├── workspace/       # AGENTS.md, SOUL.md, etc.
│   │   └── agents/pm/       # Session store
│   └── project/             # Git repo 副本 (只读参考)
│
├── agent-eng/
│   ├── .openclaw/           # Gateway 配置 (port 18790)
│   │   ├── openclaw.json
│   │   └── workspace/
│   ├── project/             # Git repo 副本 (读写，编码用)
│   └── .codex/              # Codex CLI 配置
│
├── agent-test/
│   ├── .openclaw/           # Gateway 配置 (port 18791)
│   │   ├── openclaw.json
│   │   └── workspace/
│   └── project/             # Git repo 副本 (读写，跑测试用)
│
└── agent-devops/
    ├── .openclaw/           # Gateway 配置 (port 18792)
    │   ├── openclaw.json
    │   └── workspace/
    └── project/             # Git repo 副本 (merge + deploy)
```

**要点：**

- 每个 agent 拥有独立的 home 目录（通过 Linux 用户隔离或目录约定）
- 每个 agent clone 独立的 project repo 副本，避免 git 操作冲突
- PM 的 project 副本是只读参考，不需要写代码
- Engineer 和 Tester 各自在自己的副本上工作

### 2.3 Slack Channel 设计

```
#ai-dev-team (单一 channel)
├── @pm-bot      ← Slack App 1, 绑定 OpenClaw PM 进程
├── @eng-bot     ← Slack App 2, 绑定 OpenClaw Engineer 进程
├── @test-bot    ← Slack App 3, 绑定 OpenClaw Tester 进程
├── @devops-bot  ← Slack App 4, 绑定 OpenClaw DevOps 进程
└── 人类成员
```

**Channel 行为规则：**

- 所有 4 个 bot 加入同一个 `#ai-dev-team` channel
- 每个 bot 设置 `requireMention: true`，只在被 @mention 时响应
- Bot 之间可以通过 @mention 触发对方（Slack app_mention event）
- 不带 @mention 的普通消息，4 个 bot 都不响应

---

## 3. GitHub 任务管理体系

### 3.1 Label 体系

**状态 Label（互斥，一个 Issue 同时只有一个状态）：**

| Label | 含义 | 当前负责人 |
|-------|------|-----------|
| `status/planning` | PM 正在规划中 | PM |
| `status/ready-for-dev` | 等待 Engineer 领取 | — |
| `status/in-progress` | Engineer 正在开发 | Engineer |
| `status/ready-for-test` | 开发完成，等待测试 | — |
| `status/testing` | Tester 正在测试 | Tester |
| `status/test-failed` | 测试失败，需要修复 | Engineer |
| `status/ready-for-deploy` | 测试通过，等待部署 | — |
| `status/deploying` | DevOps 正在部署 | DevOps |
| `status/done` | 已完成 | — |

**优先级 Label：**

| Label | 含义 |
|-------|------|
| `priority/high` | 优先处理 |
| `priority/medium` | 正常排期 |
| `priority/low` | 空闲时处理 |

**类型 Label：**

| Label | 含义 |
|-------|------|
| `type/feature` | 新功能 |
| `type/bugfix` | 修复 |
| `type/refactor` | 重构 |

### 3.2 Issue Template

每个 Issue 使用如下结构：

```markdown
## 需求描述
[PM 填写：清晰描述要做什么]

## Acceptance Criteria
- [ ] AC1: 具体的、可验证的条件
- [ ] AC2: 具体的、可验证的条件
- [ ] AC3: 具体的、可验证的条件

## 技术方案
[Engineer 填写]

## 测试报告
[Tester 填写]

## 部署信息
[DevOps 填写]
```

### 3.3 状态流转图

```
人类需求 (Slack)
    │
    ▼
[status/planning] ──PM拆分完成──▶ [status/ready-for-dev]
                                        │
                                        ▼
                                 [status/in-progress]
                                        │
                                   开发完成+测试通过
                                        │
                                        ▼
                                [status/ready-for-test]
                                        │
                               ┌────────┴────────┐
                               ▼                 ▼
                      [status/testing]    (Tester 检查)
                               │
                      ┌────────┴────────┐
                      ▼                 ▼
              测试通过               测试失败
                      │                 │
                      ▼                 ▼
          [status/ready-for-deploy]  [status/test-failed]
                      │                 │
                      ▼                 ▼
              [status/deploying]    回到 [status/in-progress]
                      │             (Engineer 修复)
                      ▼
               [status/done]
```

### 3.4 退出机制

为防止无限循环，设定以下规则：

- Engineer 修复同一 Issue 的 test-failed 最多 **3 次**
- 第 3 次仍然失败，Issue 标记 `status/blocked`，在 Slack 通知人类介入
- PM 的 heartbeat 检查是否有 Issue 在某个状态停留超过 **60 分钟**，超时则 Slack 提醒

---

## 4. 角色定义与工作流

### 4.1 PM Agent

**职责：** 需求理解、任务拆分、优先级管理、进度监控

**触发方式：**

| 触发 | 场景 |
|------|------|
| Slack @mention | 人类描述新需求 |
| Heartbeat (30min) | 检查停滞任务、检查 test-failed 需要重新评估的 Issue |

**工作流：**

```
1. 收到需求描述
2. 分析需求，拆分为 1~3 个 GitHub Issue
3. 每个 Issue 写清楚：
   - 需求描述（做什么）
   - Acceptance Criteria（怎样算完成）
   - 优先级 Label
   - 关联 Milestone
4. 打 Label: status/ready-for-dev
5. 在 Slack @eng-bot 通知: "Issue #42 ready for dev, 请查看"
```

**工具权限：**

```json
{
  "tools": {
    "allow": ["exec", "read", "message"],
    "deny": ["write", "edit", "browser", "canvas"]
  }
}
```

**HEARTBEAT.md：**

```markdown
- Check GitHub issues with label status/test-failed, evaluate if AC needs adjustment
- Check if any issue has been in the same status for over 60 minutes, alert in Slack
- Check if there are unprocessed human messages in #ai-dev-team
```

### 4.2 Engineer Agent

**职责：** 理解需求、委派编码给 Codex CLI、质量门禁、提交 PR

**触发方式：**

| 触发 | 场景 |
|------|------|
| Slack @mention | PM 通知新任务 / Tester 报告 bug |
| Heartbeat (15min) | 检查 `status/ready-for-dev` 和 `status/test-failed` 的 Issue |

**工作流（新功能）：**

```
1. 检查 GitHub issues with label status/ready-for-dev
2. 选择最高优先级的 Issue
3. 在 Issue 上 comment "开始处理"，改 label: status/in-progress
4. git fetch && git checkout -b feat/issue-{number}
5. 阅读 Issue 的需求描述和 AC
6. 构造 Codex CLI prompt，包含：
   - 要实现的功能
   - 项目技术栈和文件 convention
   - AC 的具体要求
   - "完成后运行 pnpm test 确保所有测试通过"
7. 执行: codex --approval-mode full-auto "<prompt>"
8. 检查 Codex 输出：
   - 如果测试通过: git add → git commit → git push → gh pr create
   - 如果测试失败: 再次调用 Codex 修复，最多重试 3 次
   - 3 次仍失败: 在 Issue comment 说明卡点，Slack 通知人类
9. PR 创建后，改 label: status/ready-for-test
10. 在 Slack @test-bot 通知: "Issue #42 PR ready for test"
```

**工作流（修复 test-failed）：**

```
1. 读 Issue 上 Tester 的测试报告 comment
2. 理解失败原因
3. checkout 对应 branch
4. 调用 Codex CLI 修复
5. push + 更新 PR
6. 改 label: status/ready-for-test
7. 在 Slack @test-bot 通知修复完成
```

**工具权限：**

```json
{
  "tools": {
    "allow": ["exec", "read", "write", "edit", "message"],
    "deny": ["browser", "canvas"]
  }
}
```

**环境依赖：**

- Codex CLI 已安装并配置 OpenAI API key
- 项目 repo 已 clone 到 `/home/agent-eng/project/`
- Node.js 22+, pnpm 已安装

**Codex CLI 调用模板：**

```bash
cd /home/agent-eng/project && \
codex --approval-mode full-auto \
  "根据以下需求实现功能，完成后运行 pnpm test 确保通过。

需求: {从 Issue 提取的需求描述}

Acceptance Criteria:
{从 Issue 提取的 AC 列表}

技术要求:
- Next.js App Router API routes
- Supabase client 使用 @supabase/supabase-js
- TypeScript strict mode
- 编写对应的 vitest 测试用例"
```

### 4.3 Tester Agent

**职责：** 独立环境验证、AC 逐条核对、测试报告

**触发方式：**

| 触发 | 场景 |
|------|------|
| Slack @mention | Engineer 通知 PR ready |
| Heartbeat (15min) | 检查 `status/ready-for-test` 的 Issue |

**工作流：**

```
1. 检查 GitHub issues with label status/ready-for-test
2. 找到关联的 PR，获取 branch name
3. 在自己的 repo 副本: git fetch && git checkout {branch}
4. 安装依赖: pnpm install
5. 运行测试: pnpm test
6. 如果有 API endpoint，用 curl 做集成验证:
   - 启动 dev server (后台): pnpm dev &
   - 等待启动: sleep 5
   - 逐条验证 AC
   - 关闭 dev server
7. 在 Issue 上 comment 测试报告:
   - 测试命令和结果
   - 每条 AC 的验证状态 (pass/fail)
   - 失败原因描述
8. 全部通过:
   - 改 label: status/ready-for-deploy
   - 在 Slack @devops-bot 通知
9. 有失败:
   - 改 label: status/test-failed
   - 在 Slack @eng-bot 通知，附失败摘要
```

**测试策略 (Phase 1 - 初期简化版)：**

- 只做 API 级别的测试，不做浏览器 E2E 测试
- 测试方法：vitest 单元测试 + curl 集成测试
- 不使用 Playwright，避免 headless browser 环境问题

**工具权限：**

```json
{
  "tools": {
    "allow": ["exec", "read", "message"],
    "deny": ["write", "edit", "browser", "canvas"]
  }
}
```

**测试报告模板 (写入 Issue comment)：**

```markdown
## Test Report - Issue #{number}

**Branch:** feat/issue-{number}
**Date:** YYYY-MM-DD HH:mm

### Unit Tests
- `pnpm test` result: ✅ PASS / ❌ FAIL
- {n} tests passed, {m} failed

### API Integration Tests
- `GET /api/xxx` → ✅ 200, response matches schema
- `POST /api/xxx` with invalid body → ✅ 400, error message correct

### Acceptance Criteria Verification
- [x] AC1: description — PASS
- [ ] AC2: description — FAIL: {reason}

### Verdict: PASS ✅ / FAIL ❌
```

### 4.4 DevOps Agent

**职责：** Merge PR、触发部署、验证部署结果、通知

**触发方式：**

| 触发 | 场景 |
|------|------|
| Slack @mention | Tester 通知测试通过 |
| Heartbeat (30min) | 检查 `status/ready-for-deploy` 的 Issue |

**工作流：**

```
1. 检查 GitHub issues with label status/ready-for-deploy
2. 找到关联的 PR
3. 改 label: status/deploying
4. Merge PR to main: gh pr merge {number} --squash
5. 等待 Vercel 自动部署 (Vercel GitHub Integration)
6. 轮询部署状态 (最多等 5 分钟):
   - vercel ls --prod 或 curl Vercel API
7. 部署完成后做 health check:
   - curl https://{deployment-url}/api/health
   - 验证返回 200 + 正确 response
8. Health check 通过:
   - 改 label: status/done
   - 关闭 Issue
   - 在 Slack 通知: "Issue #42 已部署上线 ✅"
9. Health check 失败:
   - 在 Slack 报告部署异常
   - 不关闭 Issue，等待人类介入
```

**工具权限：**

```json
{
  "tools": {
    "allow": ["exec", "read", "message"],
    "deny": ["write", "edit", "browser", "canvas"]
  }
}
```

**部署配置 (写入 TOOLS.md)：**

```markdown
## Deployment
- Platform: Vercel
- Deploy trigger: push to main (GitHub Integration, 自动)
- Production URL: https://{project}.vercel.app
- Health check endpoint: GET /api/health
- Vercel CLI available: vercel --prod (备用手动部署)
```

---

## 5. 并发与消息处理模型

### 5.1 OpenClaw 的消息队列机制

每个 OpenClaw 进程的并发模型：

- **每个 session 同一时间只有一个 active run**
- 新消息在 active run 期间到达时，进入 queue
- 默认 `collect` 模式：攒积排队消息，等当前 run 结束后合并处理
- Heartbeat 跑在独立的 `cron` lane，不被 inbound 消息阻塞

### 5.2 实际场景处理

**场景 A：Engineer 正在写代码，PM @mention 它问进度**

```
1. Engineer 的 Codex CLI 正在执行中（active run）
2. PM 的 @mention 消息进入 Engineer 的 queue
3. Codex 完成 → Engineer 的 run 结束
4. Queue 中的 PM 消息作为 followup turn 被处理
5. Engineer 回复 PM 进度
```

等待时间取决于 Codex CLI 执行时长（通常 1-5 分钟）。这和人类"在写代码，等一下再回消息"一样。

**场景 B：Heartbeat 触发时正好有新 @mention**

```
1. Heartbeat 在 cron lane 中执行（检查 GitHub Issues）
2. @mention 在 main lane 中排队
3. 两者互不阻塞，可以并行
4. Heartbeat 完成后，main lane 的消息正常处理
```

**场景 C：两个 bot 同时 @mention 同一个 bot**

```
1. PM @eng-bot 和 Tester @eng-bot 几乎同时发消息
2. 先到的消息触发 agent run
3. 后到的消息进入 queue (collect 模式)
4. 第一个 run 完成后，第二条消息作为 followup 处理
```

### 5.3 Agent 间通信协议

```
通信方式: Slack @mention (通过 Slack app_mention event)
消息格式: 自然语言 + Issue 引用

示例:
  PM → Eng:  "@eng-bot Issue #42 is ready for dev. Priority: high."
  Eng → Test: "@test-bot Issue #42 PR #15 is ready for test."
  Test → Eng: "@eng-bot Issue #42 test failed. See test report in Issue comment."
  Test → Ops: "@devops-bot Issue #42 tests passed. Ready for deploy."
  Ops → All:  "Issue #42 deployed to production ✅ https://xxx.vercel.app"
```

### 5.4 防消息风暴规则

写入每个 agent 的 AGENTS.md：

```markdown
## Communication Rules
- 每次回复最多 @mention 1 个其他角色
- 不要发"收到""好的"等无意义回复，直接做事或报告结果
- 任务状态变更以 GitHub Label 为主信号，Slack @mention 为辅助通知
- 不要主动发起与任务无关的对话
- 如果被多个人同时 @mention，按优先级依次处理
```

---

## 6. 每个 Agent 的 Workspace 文件清单

### 6.1 通用结构

每个 agent 的 workspace 目录：

```
workspace/
├── AGENTS.md       # 行为规则、工作流程、通信协议
├── SOUL.md         # 人格定义、语言风格
├── TOOLS.md        # 工具说明、项目路径、环境信息
├── USER.md         # 人类主人的信息
├── HEARTBEAT.md    # 定时任务检查清单
├── MEMORY.md       # 持久化记忆（PM: 需求历史; Eng: 技术决策记录）
└── memory/         # 日常记忆目录
    └── YYYY-MM-DD.md
```

### 6.2 各角色 AGENTS.md 的核心内容概要

**PM AGENTS.md 核心：**

```
- 你是产品经理，负责需求理解和任务拆分
- 收到需求后创建 GitHub Issue，必须包含明确的 AC
- 每个 AC 必须是可验证的（可以用 curl 或 test 命令验证）
- 拆分粒度：每个 Issue 的改动控制在 1-2 个文件
- 拆分完成后改 label 并在 Slack 通知 Engineer
- 不要自己写代码
```

**Engineer AGENTS.md 核心：**

```
- 你是工程师，负责实现代码
- 开始前先在 Issue comment "🚀 开始处理"
- 使用 Codex CLI 完成编码，不要手动写代码
- Codex prompt 必须包含 AC 和"完成后跑 pnpm test"
- 测试通过后才能 push 和创建 PR
- 修复 test-failed 最多 3 次，超过后求助人类
- Git 工作流：fetch → checkout branch → codex → test → commit → push → PR
```

**Tester AGENTS.md 核心：**

```
- 你是测试工程师，负责独立验证
- checkout PR branch 到自己的 repo 副本
- 运行 pnpm test，然后用 curl 验证 API
- 逐条核对 AC
- 在 Issue 上写结构化测试报告
- 全通过改 label 通知 DevOps；有失败改 label 通知 Engineer
```

**DevOps AGENTS.md 核心：**

```
- 你是运维工程师，负责部署和环境管理
- Merge PR 使用 --squash 模式
- Vercel 自动部署，你只需等待并验证
- Health check 通过后关闭 Issue 并在 Slack 通知
- Health check 失败不要自行修复，通知人类
```

### 6.3 所有 Agent 共享的信息 (写入各自 TOOLS.md)

```markdown
## Project Info
- Repo: {owner}/{repo-name}
- Tech Stack: Next.js (App Router) + Supabase + TypeScript
- Package Manager: pnpm
- Test Framework: vitest
- Local Project Path: /home/agent-{role}/project/

## GitHub Convention
- Label prefix: status/, priority/, type/
- Branch naming: feat/issue-{number}, fix/issue-{number}
- Commit message: conventional commits (feat:, fix:, test:, chore:)

## Team Slack IDs
- PM: <@U_PM_BOT_ID>
- Engineer: <@U_ENG_BOT_ID>
- Tester: <@U_TEST_BOT_ID>
- DevOps: <@U_DEVOPS_BOT_ID>

## Slack Channel
- #ai-dev-team: 所有任务讨论和状态更新

## Production
- URL: https://{project}.vercel.app
- Health Check: GET /api/health → { "status": "ok" }
```

---

## 7. 风险清单与缓解策略

### 7.1 高风险

| # | 风险 | 影响 | 缓解策略 |
|---|------|------|---------|
| R1 | Playwright/E2E 测试在 headless 服务器上环境问题多 | Tester 卡住 | **初期不做 E2E 测试**，只用 vitest + curl |
| R2 | Engineer 修复 bug 陷入死循环 | 无限消耗 token | 设定 **3 次修复上限**，超过则 blocked + 通知人类 |
| R3 | 4 个进程共用一个 Git repo working directory | Git 冲突 | 每个 agent **独立 clone** repo 副本 |
| R4 | Agent 代码上下文有限，复杂项目难理解 | 代码质量差 | 项目初期控制在 **10 个文件以内**，每个 Issue 改 1-2 个文件 |

### 7.2 中等风险

| # | 风险 | 影响 | 缓解策略 |
|---|------|------|---------|
| R5 | GLM-5 API 超时或 rate limit | Agent run 失败 | 配 fallback model；AGENTS.md 要求失败时 Slack 报错 |
| R6 | Tester 启动 dev server 阻塞 shell | 测试流程卡住 | 后台启动 `pnpm dev &`；或用 vitest 直接测 handler 不起 server |
| R7 | Issue 在某状态停滞（agent 漏检） | 任务卡住 | PM heartbeat **检查停滞超 60 分钟**的 Issue |
| R8 | Supabase 连接配置问题 | 数据库操作失败 | `.env.local` 提前配好，写入 TOOLS.md |
| R9 | Codex CLI 输出不符预期 | 代码质量问题 | Engineer 检查 Codex 输出 + pnpm test 门禁 |

### 7.3 低风险

| # | 风险 | 影响 | 缓解策略 |
|---|------|------|---------|
| R10 | Heartbeat token 消耗 | 成本增加 | Heartbeat 用便宜模型，HEARTBEAT.md 保持极短 |
| R11 | Slack 消息风暴 | 频道刷屏 | AGENTS.md 限制每次回复最多 @mention 1 人 |
| R12 | 项目初始化的鸡生蛋问题 | 浪费时间 | **人工初始化**项目，给 agent 已经能跑的项目 |

---

## 8. OpenClaw 配置模板

### 8.1 通用 openclaw.json 模板 (以 PM 为例)

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "glm/glm-5",
        "fallbacks": ["glm/glm-4-plus"]
      },
      "heartbeat": {
        "every": "30m",
        "model": "glm/glm-4-flash"
      },
      "maxConcurrent": 2
    }
  },
  "gateway": {
    "port": 18789,
    "bind": "127.0.0.1"
  },
  "channels": {
    "slack": {
      "enabled": true,
      "mode": "socket",
      "appToken": "xapp-...",
      "botToken": "xoxb-...",
      "groupPolicy": "allowlist",
      "channels": {
        "#ai-dev-team": {
          "allow": true,
          "requireMention": true
        }
      },
      "dm": {
        "enabled": false
      },
      "streaming": "partial"
    }
  },
  "messages": {
    "queue": {
      "mode": "collect",
      "debounceMs": 1000,
      "cap": 10
    }
  }
}
```

**各角色差异点：**

| 配置项 | PM | Engineer | Tester | DevOps |
|--------|-----|----------|--------|--------|
| port | 18789 | 18790 | 18791 | 18792 |
| heartbeat.every | 30m | 15m | 15m | 30m |
| tools.allow | exec,read,message | exec,read,write,edit,message | exec,read,message | exec,read,message |

### 8.2 Slack App 创建清单 (重复 4 次)

每个 Slack App 需要：

1. 在 api.slack.com/apps 创建 App (From scratch)
2. 启用 Socket Mode → 生成 App Token (xapp-...)
3. OAuth & Permissions → 添加 Bot Token Scopes:
   - `chat:write`, `channels:history`, `channels:read`
   - `groups:history`, `im:history`, `users:read`
   - `app_mentions:read`, `reactions:read`, `reactions:write`
4. Event Subscriptions → 订阅:
   - `app_mention`, `message.channels`
5. 安装到 workspace → 获取 Bot Token (xoxb-...)
6. 邀请 bot 到 `#ai-dev-team` channel

---

## 9. Demo 选题与渐进路线

### Phase 1: 最小闭环验证

**Demo 1: Health Check API**

```
需求: 创建 GET /api/health，返回 { status: "ok", timestamp: "..." }
涉及文件: 1 个 (app/api/health/route.ts)
测试方式: curl
预期耗时: 全链路 < 30 分钟
```

### Phase 2: 引入 Supabase

**Demo 2: User CRUD API**

```
需求: POST /api/users (创建) + GET /api/users/:id (查询)
涉及文件: 2-3 个 (route + supabase client + test)
测试方式: vitest + curl
新增复杂度: Supabase 连接、数据库表创建
```

### Phase 3: 增加业务逻辑

**Demo 3: Input Validation**

```
需求: 给 /api/users 添加 zod schema 验证
涉及文件: 1-2 个
测试方式: vitest (测试各种 invalid input)
新增复杂度: 第三方库、错误处理
```

### Phase 4: 完整功能

**Demo 4: 订单查询 API**

```
需求: GET /api/orders?userId=xxx，返回最近 5 条订单
涉及文件: 2-3 个
测试方式: vitest + curl
新增复杂度: 多表查询、分页
```

---

## 10. 7 天执行计划

### Day 1: 基础设施 — 单 Agent 跑通

**目标：** 1 个 OpenClaw 进程在 VPS 上运行，连接 Slack，能对话和操作 GitHub

**步骤：**

```bash
# 1. 服务器环境
node -v  # 确认 Node 22+
npm install -g openclaw@latest
npm install -g @openai/codex  # 安装 Codex CLI

# 2. 创建第一个 agent (PM) 并 onboard
mkdir -p /home/agent-pm
cd /home/agent-pm
openclaw onboard --install-daemon

# 3. 配置 GLM-5 API key
# 4. 创建 Slack App #1 (pm-bot), 获取 tokens
# 5. 配置 openclaw.json，设定 Slack channel
# 6. 启动 Gateway
openclaw gateway --port 18789

# 7. 在 Slack #ai-dev-team 测试对话
# 8. 安装 GitHub skill
openclaw skills install github
# 9. 测试 GitHub 操作（创建 Issue）
```

**验证标准：** 在 Slack @pm-bot → 能回复 → 能创建 GitHub Issue

### Day 2: 4 个进程全部跑通 + Slack 联调

**目标：** 4 个 bot 在 `#ai-dev-team` channel 里都能响应 @mention

**步骤：**

```bash
# 对 agent-eng, agent-test, agent-devops 重复 Day 1 步骤
# 创建 Slack App #2, #3, #4
# 配置不同端口 (18790, 18791, 18792)
# 用 systemd 管理 4 个进程

# 测试:
# 1. 在 Slack @pm-bot "hello" → PM 回复
# 2. 在 Slack @eng-bot "hello" → Engineer 回复
# 3. Bot A @mention Bot B → Bot B 被触发并回复
```

**验证标准：** 4 个 bot 都能独立响应，bot 间 @mention 能触发对方

### Day 3: 项目初始化 + AGENTS.md 编写

**目标：** Next.js 项目能跑，4 份 AGENTS.md 写完

**步骤：**

```bash
# 1. 手动初始化项目 (人工操作)
npx create-next-app@latest project-name --typescript --app --tailwind
cd project-name
pnpm add @supabase/supabase-js zod
pnpm add -D vitest
# 配置 vitest, 创建 .env.local
# push 到 GitHub

# 2. 每个 agent clone 项目
git clone ... /home/agent-pm/project/
git clone ... /home/agent-eng/project/
git clone ... /home/agent-test/project/
git clone ... /home/agent-devops/project/

# 3. 在 GitHub repo 创建所有 Label
# 4. 编写 4 份 AGENTS.md, SOUL.md, TOOLS.md, HEARTBEAT.md

# 5. 配置 Codex CLI 给 Engineer
# /home/agent-eng/.codex/ 配置 OpenAI API key
```

**验证标准：** `pnpm dev` 能跑；`pnpm test` 有一个 placeholder test 通过

### Day 4: PM → Engineer 半链路

**目标：** PM 创建 Issue → Engineer 写代码 → PR 出来

**步骤：**

```
1. 在 Slack: @pm-bot "我们需要一个 health check API，GET /api/health 返回 status ok"
2. 观察 PM 是否正确创建 Issue + AC + Label
3. 观察 Engineer 是否被 @mention 触发
4. 观察 Engineer 是否调用 Codex CLI 实现功能
5. 观察 PR 是否被创建
6. 如果失败，调试 AGENTS.md 的 prompt
```

**验证标准：** GitHub 上出现 Issue + PR

### Day 5: Tester → DevOps 半链路

**目标：** Tester 验证通过 → DevOps 部署上线

**步骤：**

```
1. 手动将 Day 4 的 PR 标记为 status/ready-for-test
2. 在 Slack @test-bot 通知
3. 观察 Tester 是否 checkout + 跑测试 + 写报告
4. 观察 label 是否变为 status/ready-for-deploy
5. 观察 DevOps 是否 merge + 等部署 + health check
6. 观察 Slack 是否收到部署通知
```

**验证标准：** Vercel 上线 + health check 通过

### Day 6: 全链路联调

**目标：** 端到端一条龙自动走通

**步骤：**

```
1. 新需求: "创建 GET /api/ping 返回 { pong: true, time: Date.now() }"
2. 只在 Slack 说一句话，然后观察
3. PM → Issue → Engineer → PR → Tester → Test Report → DevOps → Deploy
4. 记录每个阶段耗时
5. 记录遇到的问题，调整 AGENTS.md
```

**验证标准：** 从 Slack 消息到 Vercel 上线，全程无人工干预

### Day 7: 第二个真实任务 + 加固

**目标：** 用 Supabase 的 CRUD 任务验证 + 完善异常处理

**步骤：**

```
1. 需求: "创建 users 表的 CRUD API"
2. 全链路跑一遍
3. 故意制造异常测试:
   - 写一个 bug 看 test-failed 流程是否正常
   - 人工修改 label 测试是否能恢复
4. 完善 PM 的停滞检测 heartbeat
5. workspace 推到 private git repo 做备份
6. 写团队使用说明
```

**验证标准：** CRUD API 上线 + 异常流程验证通过

---

## 11. 后续演进方向 (Phase 2+)

- 引入前端开发任务，逐步加入 Playwright E2E 测试
- 用 Supabase MCP server 让 DevOps 直接管理数据库 migration
- 引入 Code Review 环节（可以是第 5 个 agent，或由 Tester 兼任）
- 建立项目知识库（MEMORY.md 积累技术决策记录）
- 探索 Vercel Preview Deployment 用于 PR 预览
- 加入成本监控（token 消耗追踪）