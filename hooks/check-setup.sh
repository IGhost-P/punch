#!/bin/bash
# Runs on SessionStart — checks if Punch credentials exist

CRED="$HOME/.punch/credentials.json"

if [ ! -f "$CRED" ]; then
  echo '{"userMessage":"[Punch] No credentials found. Run /punch:setup to connect GitLab & Jira."}'
  exit 0
fi

GITLAB_URL=$(jq -r '.gitlab.url // empty' "$CRED" 2>/dev/null)
JIRA_URL=$(jq -r '.jira.url // empty' "$CRED" 2>/dev/null)

MISSING=""
[ -z "$GITLAB_URL" ] && MISSING="GitLab"
[ -z "$JIRA_URL" ] && { [ -n "$MISSING" ] && MISSING="$MISSING & Jira" || MISSING="Jira"; }

if [ -n "$MISSING" ]; then
  echo "{\"userMessage\":\"[Punch] $MISSING config incomplete. Run /punch:setup to fix.\"}"
fi

exit 0
