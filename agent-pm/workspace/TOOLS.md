# PM Agent Tool Notes

This file is your reference for how to use your tools in this specific environment. TOOLS.md doesn't control which tools exist — it's guidance for how you should use them.

---

## GitHub CLI (`gh`)

You use GitHub CLI for all Issue and Milestone management.

### Common Commands

```bash
# List open issues with labels
gh issue list --repo OWNER/REPO --state open --label "status/ready-for-dev"

# Create an issue
gh issue create --repo OWNER/REPO \
  --title "Add GET /api/health endpoint" \
  --body "$(cat <<'EOF'
## Context
...
## Reporter
@alice
## Acceptance Criteria
- [ ] ...
## Scope
...
EOF
)" \
  --label "status/planning" --label "priority/p1" \
  --milestone "v0.1"

# Update labels (remove old, add new)
gh issue edit 12 --repo OWNER/REPO \
  --remove-label "status/planning" \
  --add-label "status/ready-for-dev"

# Close an issue
gh issue close 12 --repo OWNER/REPO

# List milestones
gh api repos/OWNER/REPO/milestones

# View issue details
gh issue view 12 --repo OWNER/REPO
```

### Label Naming Convention

All status labels: `status/{state}` (lowercase, hyphenated).
All priority labels: `priority/p{0-2}`.

### Repo Details

- **Repo:** `${GITHUB_OWNER}/${GITHUB_REPO}`
- **Default branch:** `main`
- **Milestone for current sprint:** (to be filled)

---

## Slack Messaging

You communicate via Slack `message` tool to the channel specified by `$SLACK_CHANNEL` environment variable.

### Message Guidelines

- Include Issue number in every work-related message.
- Keep messages under 300 characters when possible. Long messages get skimmed.
- For structured updates (milestone summaries), use a brief list format.

### Channel

- Primary channel: `$SLACK_CHANNEL` (channel ID from environment variable)
- Do NOT message other channels unless explicitly told to.

---

## File Reading

You can `read` files from:
- Your workspace (`${OPENCLAW_HOME}`)

---

## What You Cannot Do

- `write` / `edit` — you cannot modify project source files.
- `browser` / `canvas` — no web browsing or UI rendering.
- You cannot directly push to git. Leave that to Engineer and DevOps.
- You cannot access other agents' workspaces directly.

---

## Troubleshooting

### GitHub CLI not authenticated

```bash
gh auth status
```

If it fails, this is a setup issue — report to human.

### Slack message not sending

If `message` tool returns an error:
- Note the error in your daily log.
- Retry once.
- If still failing, this is an infrastructure issue. Wait for next heartbeat.

### Issue labels not found

Labels must be pre-created in the GitHub repo. If `gh issue edit --add-label "status/xxx"` fails with "label not found":
- Report to human: "Label `status/xxx` doesn't exist in the repo. Can you create it?"
- Do not try to create labels yourself (it may require admin perms).