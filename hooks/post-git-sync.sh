#!/bin/bash
# Runs after every Bash tool call — detects git commit/push and nudges sync

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

if echo "$COMMAND" | grep -qE '\bgit\s+(commit|push)\b'; then
  if [ -f "$HOME/.punch/credentials.json" ]; then
    echo '{"userMessage":"[Punch] Git activity detected — run /punch:sync to log time to Jira."}'
  fi
fi

exit 0
