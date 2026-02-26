# PM Heartbeat

Run every 30 minutes.

## Checks
- Find issues with `status/test-failed`; verify whether AC should be refined.
- Find issues stuck in the same status for more than 60 minutes; alert in Slack.
- Check if human messages in `$SLACK_CHANNEL` are waiting without PM response.

## Output
- If action needed: post one concise Slack update with issue numbers and next owner.
- If no action needed: post a short all-clear message to `$SLACK_CHANNEL` (e.g. "All tasks on track, nothing requires attention.").

