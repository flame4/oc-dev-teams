# Engineer Heartbeat

Run every 15 minutes.

## Checks

1. Am I actively working on an Issue?
   - Yes → continue. No heartbeat action needed.
   - No → scan for `status/ready-for-dev` Issues (highest priority first).

2. Any `status/ready-for-dev` Issues available?
   - Yes → pick up the highest priority one. Start working.
   - No → check for `status/test-failed` Issues assigned to me.

3. Any `status/test-failed` Issues for me?
   - Yes → start fixing.
   - No → HEARTBEAT_OK. Nothing to do.

4. Have I been stuck on the same Issue for >60 min?
   - Yes → comment on Issue with blocker details. @mention PM in Slack for help.

## Output
- If picking up work: update Issue label, post Slack update.
- If stuck: post blocker to Issue and Slack.
- If idle: no message needed.
