# QA Agent Tool Notes

This file is your reference for how to use your tools in this specific environment.

---

## Testing Tools

### vitest (via pnpm)

Your primary test runner. Run the full suite or specific test files.

```bash
# Run all tests
pnpm test

# Run specific test file
pnpm test -- --run src/app/api/health/route.test.ts

# Run tests with verbose output
pnpm test -- --run --reporter=verbose
```

### curl (API Testing)

For testing API endpoints directly.

```bash
# GET request
curl -s -w "\nHTTP_STATUS: %{http_code}\n" \
  http://localhost:3000/api/health

# POST request with JSON body
curl -s -w "\nHTTP_STATUS: %{http_code}\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"name": "test"}' \
  http://localhost:3000/api/users

# GET with query params
curl -s -w "\nHTTP_STATUS: %{http_code}\n" \
  "http://localhost:3000/api/users?id=123"

# Production endpoint check
curl -s -w "\nHTTP_STATUS: %{http_code}\n" \
  "${PRODUCTION_BASE_URL}/api/health"
```

### Tips for Testing

- Always run `pnpm install` before testing to ensure deps are current.
- When testing a PR branch, `git fetch origin && git checkout {branch}` first.
- Capture full test output for reports — include errors, stack traces, and exit codes.
- Compare actual API responses against the AC's expected behavior point by point.

---

## Git

### Common Commands

```bash
# Fetch and checkout PR branch for testing
git fetch origin
git checkout feat/issue-12-health-endpoint

# Pull latest changes (for re-testing after fix)
git pull origin feat/issue-12-health-endpoint

# Check which branch you're on
git branch --show-current

# View recent commits on the branch
git log --oneline -5
```

### Important

- You are **read-only** on source code. Never commit or push changes.
- Use git only for checking out branches and reading code.

---

## GitHub CLI (`gh`)

### Common Commands

```bash
# View Issue details
gh issue view 12 --repo OWNER/REPO

# Update Issue labels
gh issue edit 12 --repo OWNER/REPO \
  --remove-label "status/ready-for-test" \
  --add-label "status/testing"

# Comment on Issue (test report)
gh issue comment 12 --repo OWNER/REPO \
  --body "## Test Report ✅
All tests passed. Ready for deploy."

# Create bug Issue
gh issue create --repo OWNER/REPO \
  --title "Bug: GET /api/users returns 500" \
  --body "## Bug Report..." \
  --label "bug,status/ready-for-dev,priority/P1"

# List Issues ready for test
gh issue list --repo OWNER/REPO --label "status/ready-for-test"

# List test-failed Issues
gh issue list --repo OWNER/REPO --label "status/test-failed"

# View PR details
gh pr view 5 --repo OWNER/REPO
```

### Repo Details

- **Repo:** `${GITHUB_OWNER}/${GITHUB_REPO}`
- **Default branch:** `main`

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

You can `read` files in:
- Your workspace (`${OPENCLAW_HOME}`) — but only `MEMORY.md` and `memory/*` for writing
- The project repo (`${OPENCLAW_HOME}/project/`) — read-only for source code and test files

---

## What You Cannot Do

- `write` / `edit` — no modifying project source code.
- `browser` / `canvas` — no web browsing or UI rendering.
- Modify workspace config files (AGENTS.md, SOUL.md, etc.) — read-only.
- Push to any branch or commit changes.
- Access other agents' workspaces directly.

---

## Troubleshooting

### Tests failing to run at all

```bash
pnpm --version    # Check pnpm is installed
pnpm install      # Ensure deps are installed
pnpm test 2>&1    # Capture full error output
```

If tests can't run at all (missing deps, config errors), report to human — this is a setup issue.

### GitHub CLI not authenticated

```bash
gh auth status
```

If it fails, report to human — this is a setup issue.

### Can't checkout PR branch

```bash
git fetch origin              # Fetch latest refs
git branch -a                 # List all branches
git checkout {branch-name}    # Try again
```

If the branch doesn't exist, check the Issue/PR for the correct branch name.
