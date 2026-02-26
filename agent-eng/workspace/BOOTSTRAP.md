# Engineer Agent First Run

This is your birth certificate. Run through it once, then delete this file.

---

## Step 1: Orient Yourself

Read all workspace files:
- `AGENTS.md` — your operating manual (read-only, never modify)
- `SOUL.md` — your personality (read-only)
- `TOOLS.md` — your tool reference (read-only)
- `HEARTBEAT.md` — your heartbeat checklist (read-only)
- `IDENTITY.md` — who you are (read-only)

## Step 2: Fetch Your Slack User ID

Before introducing yourself, you need your own Slack user ID so others can @mention you.

```bash
# Use Slack API to get your own bot user ID
# The bot token is in your environment as SLACK_BOT_TOKEN
curl -s -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
  https://slack.com/api/auth.test | jq -r '.user_id'
```

Save this ID (format: `U0XXXXXXXXX`). Update the `Slack ID` column for your own row in `MEMORY.md`.

## Step 3: Initialize Memory Directory

Create `memory/` directory:

```bash
mkdir -p memory
```

Your `MEMORY.md` already exists as a template. Update your Slack ID in it now.

## Step 4: Introduce Yourself to PM

PM Bot is already online. The human will tell you PM's Slack user ID — or it may already be in the channel.

Send a message to `#ai-dev-team` that includes your Slack user ID so PM can record it:

> "<@{PM_SLACK_ID}> Hi, I'm eng-bot (Engineer agent). My Slack user ID is `{YOUR_SLACK_ID}`. I handle full-stack development: Next.js (App Router), Supabase, TypeScript. I'll pick up Issues labeled `status/ready-for-dev`, write code, run tests, and create PRs. Ready to build."

**Important:** If you don't know PM's Slack ID yet, just post without the @mention and state that you need PM's ID. The human will provide it.

Wait for PM to acknowledge. PM will share their own Slack ID and any current project context. **Record PM's Slack ID in MEMORY.md immediately.**

## Step 5: Gather Project Context

After PM responds, ask or discover:
- What repo are we working with? (`GITHUB_OWNER/GITHUB_REPO`)
- Is there a current Milestone?
- Any active Issues?

Record everything in `MEMORY.md` and `memory/project.md`.

## Step 6: Wait for Team Introductions

PM will introduce other bots to you. Each bot will tell you their Slack user ID. **Record every team member in `MEMORY.md`** with all fields: Name, Type, Role, Slack ID, GitHub.

## Step 7: Verify Your Tools

Run a quick check:
```bash
# Check git access
git status

# Check GitHub CLI
gh auth status

# Check Claude Code CLI
claude --version

# Check project deps
pnpm --version
```

Note any issues in `MEMORY.md`.

## Step 8: Clean Up

Delete this file (`BOOTSTRAP.md`). You're done bootstrapping.

Time to build. Pick up your first Issue when PM assigns one.
