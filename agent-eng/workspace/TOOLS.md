# Engineer Agent Tool Notes

This file is your reference for how to use your tools in this specific environment.

---

## Claude Code CLI

Your primary coding tool. Invoked via command line.

### Environment Variables

```bash
ANTHROPIC_API_KEY    # API key (set in .env, points to GLM via compatible endpoint)
ANTHROPIC_BASE_URL   # API base URL (set in .env)
ANTHROPIC_DEFAULT_OPUS_MODEL      # Model to use (set in .env, e.g. glm-4.6v)
```

### Usage Pattern

```bash
# For implementing a feature:
claude -p "$(cat <<'PROMPT'
You are working on a Next.js (App Router) + Supabase + TypeScript project.

## Task
{Issue description and AC here}

## Existing Code Context
{relevant file contents or structure}

## Instructions
- Implement according to the AC.
- Follow existing code patterns.
- Run pnpm test when done.
PROMPT
)"

# For fixing a test failure:
claude  -p "$(cat <<'PROMPT'
## Bug Report
{Tester's failure report}

## Current Code
{relevant files}

## Fix Instructions
- Fix the issue described above.
- Ensure all existing tests still pass.
- Run pnpm test.
PROMPT
)"
```

### Tips

- Always include AC in the prompt — the CLI doesn't have Issue context.
- Include relevant existing code so the CLI follows project patterns.
- Review output before committing. You own the code quality.
- If output is wrong, refine the prompt with more context and re-run.

---

## Git

### Common Commands

```bash
# Create feature branch
git checkout -b feat/issue-12-health-endpoint

# Stage and commit
git add src/app/api/health/route.ts
git commit -m "feat(#12): add GET /api/health endpoint"

# Push and create PR
git push -u origin feat/issue-12-health-endpoint
gh pr create --title "#12: Add GET /api/health endpoint" \
  --body "Closes #12" \
  --base main
```

### Branch Naming

- Feature: `feat/issue-{number}-{short-desc}`
- Fix: `fix/issue-{number}-{short-desc}`

### Commit Messages

- Format: `{type}(#{issue}): {description}`
- Types: `feat`, `fix`, `test`, `refactor`, `chore`

---

## GitHub CLI (`gh`)

### Common Commands

```bash
# View Issue details
gh issue view 12 --repo OWNER/REPO

# Update Issue labels
gh issue edit 12 --repo OWNER/REPO \
  --remove-label "status/ready-for-dev" \
  --add-label "status/in-progress"

# Create PR
gh pr create --title "#12: Feature title" \
  --body "Closes #12" --base main

# Comment on Issue
gh issue comment 12 --repo OWNER/REPO \
  --body "Starting implementation. Branch: feat/issue-12-xxx"

# List Issues ready for dev
gh issue list --repo OWNER/REPO --label "status/ready-for-dev"
```

### Repo Details

- **Repo:** `${GITHUB_OWNER}/${GITHUB_REPO}`
- **Default branch:** `main`

---

## pnpm & Testing

```bash
# Install deps
pnpm install

# Run all tests
pnpm test

# Run specific test file
pnpm test -- --run src/app/api/health/route.test.ts

# Dev server (rarely needed — prefer direct testing)
pnpm dev
```

---

## Slack Messaging

Communicate via Slack `message` tool to the channel specified by `$SLACK_CHANNEL` environment variable.

### Guidelines

- Include Issue number in every work-related message.
- Keep messages under 300 characters.
- One @mention per message.

### Channel

- Primary channel: `$SLACK_CHANNEL` (channel ID from environment variable)

---

## File Operations

You can `read`, `write`, and `edit` files in:
- Your workspace (`${OPENCLAW_HOME}`) — but only `MEMORY.md` and `memory/*` for workspace files
- The project repo (`${OPENCLAW_HOME}/project/`) — full read/write for source code

---

## What You Cannot Do

- `browser` / `canvas` — no web browsing or UI rendering.
- Modify workspace config files (AGENTS.md, SOUL.md, etc.) — read-only.
- Force-push to `main`.
- Access other agents' workspaces directly.

---

## Troubleshooting

### Claude Code CLI not responding

```bash
claude --version  # Check if CLI is installed
echo $ANTHROPIC_API_KEY  # Check API key is set (should show value)
echo $ANTHROPIC_BASE_URL  # Check base URL is set
```

If the CLI fails, note the error and try again with a simpler prompt. If it keeps failing, report to human.

### GitHub CLI not authenticated

```bash
gh auth status
```

If it fails, report to human — this is a setup issue.

### Tests failing unexpectedly

- Check if it's a test environment issue vs actual code bug.
- Run `pnpm install` first to ensure deps are current.
- Check if another branch's changes were merged that conflict.
