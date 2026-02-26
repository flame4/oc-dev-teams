# QA Heartbeat

Run every 15 minutes.

## Checks

1. Am I actively testing an Issue?
   - Yes → continue. No heartbeat action needed.
   - No → scan for `status/ready-for-test` Issues.

2. Any `status/ready-for-test` Issues available?
   - Yes → pick up the highest priority one. Start testing.
   - No → check for `status/test-failed` Issues that Engineer may have fixed (look for new commits on the PR branch).

3. Any recently fixed `status/test-failed` Issues to re-test?
   - Yes → pull latest, re-run tests.
   - No → check bug tracking (`memory/bugs.md`).

4. Any open bugs in `memory/bugs.md` that need follow-up?
   - Yes → check their Issue status. If `status/in-progress`, note progress. If stale (>60 min), nudge Engineer or PM.
   - No → HEARTBEAT_OK. Nothing to do.

5. Have any Issues been stuck in `status/testing` for >60 min (my own work)?
   - Yes → something's wrong. Post blocker details to Issue and @mention PM.

## Output
- If picking up testing: update Issue label, post Slack update.
- If re-testing a fix: post results on Issue and Slack.
- If following up on bugs: nudge if stale, otherwise note progress.
- If idle: no message needed.
