---
name: sync
description: "Sync your day — worklogs, issue updates, and comments from GitLab to Jira"
---

# /punch:sync

The main command. Reads GitLab activity and proposes **three types of Jira updates** in a single preview — worklogs, issue status transitions, and comments. Nothing happens without explicit user approval.

## Usage

```
/punch:sync today
/punch:sync this-week
/punch:sync 2026-03-10
/punch:sync 2026-03-10..2026-03-12
```

**Trigger keywords:** "오늘 정리해줘", "하루 마무리", "punch in", "sync my day", "오늘 작업 동기화"

---

## Pre-flight: Tool Detection

**Punch is tool-agnostic.** It uses whatever GitLab/Jira tools are already available — from IDE plugins, Claude Code MCP, Cursor MCP, or any source.

### Detect Available Tools

Try a lightweight read-only call for each:

**GitLab** — look for tools in this order:
1. `mcp__gitlab__*` or `mcp__punch-gitlab__*` (Claude Code MCP)
2. `user-*gitlab*` (Cursor/IDE MCP)
3. Any tool that can list commits, list projects, or get a user

**Jira** — look for tools in this order:
1. `mcp__jira__*` or `mcp__punch-jira__*` (Claude Code MCP)
2. `user-Confluence-jira_*` or `user-*jira*` (Cursor/IDE MCP)
3. Any tool named `jira_search`, `jira_add_worklog`, etc.

**Test each by actually calling it.** A tool that exists but returns an auth error is not "connected."

```
╭─────────────────────────────────────────────╮
│   ⚡ Punch Sync                              │
╰─────────────────────────────────────────────╯

  ■ Connections
  │
  ├─ GitLab   ● ready     via Cursor plugin
  └─ Jira     ● ready     via Confluence MCP
```

### Failure handling

| Situation | Display |
|-----------|---------|
| No GitLab tools | `├─ GitLab   ○ missing` → guide to `/punch:setup` |
| No Jira tools | `└─ Jira     ○ missing` → guide to `/punch:setup` |
| GitLab auth error | `├─ GitLab   ✗ auth failed` → check token |
| Jira auth error | `└─ Jira     ✗ auth failed` → check token |
| GitLab OK, Jira missing | Offer dry-run mode (preview without writing) |
| Both missing | Guide to `/punch:setup` |

**Remember the detected tool names** for use throughout the rest of the flow. For example, if Jira tools are at `user-Confluence-jira_*`, use that namespace for all subsequent Jira calls.

---

## Step 1: Parse Date Range

From the user's arguments:
- `today` (default if empty) — today only
- `this-week` — Monday through today
- `YYYY-MM-DD` — specific date
- `YYYY-MM-DD..YYYY-MM-DD` — date range

---

## Step 2: Identify GitLab Projects

Auto-detect: run `git remote -v` to find the current GitLab project.

If not in a git repo, use GitLab MCP to list user's projects. If many, ask which to scan.

---

## Step 3: Fetch All GitLab Activity

Fetch **all** activity types for the user within the date range:

| Category | Source | What it captures |
|----------|--------|------------------|
| **Commits** | `list_commits` or Events API | Code pushed |
| **MR Created** | Events API (`created` + `merge_request`) | MR preparation |
| **MR Merged** | Events API (`merged`) | Final review + merge |
| **Code Review** | MR notes/discussions | Reviewing others' MRs |
| **Issue Activity** | Events API (`created`/`commented`/`closed` + `issue`) | Issue triage |
| **Branch Created** | Events API (`pushed` with new ref) | Work started |

Fallback if Events API unavailable:
- `list_merge_requests` filtered by author/reviewer
- `git log --author=<email> --since=<date> --until=<date>`

---

## Step 4: Present Activity Summary

```
  ■ GitLab Activity — 2026-03-12
  │
  ├─ Commits        7   PROJ-101: fix dropdown alignment
  ├─ MR Created     1   !42 [PROJ-101] Dashboard widget
  ├─ MR Merged      1   !38 [PROJ-205] API response fix
  ├─ Code Review    3   Comments on !45, !47
  └─ Issue Activity 2   Commented on PROJ-310

  어떤 활동을 포함할까요? (기본: 전부)
```

---

## Step 5: Parse Jira Issue Keys

Extract keys from all selected activities:
- Branch names: `feature/PROJ-42-user-settings` → `PROJ-42`
- Commit messages: `PROJ-101: fix layout` → `PROJ-101`
- MR titles: `[PROJ-205] Add feature` → `PROJ-205`
- Issue events: directly from the issue reference

Regex: `[A-Z][A-Z0-9_]+-\d+`

---

## Step 5.5: Resolve Unlinked Activity (Smart Matching)

Not all teams put Jira keys in their commits. When activity has no detectable Jira key, Punch tries to match it automatically.

### 5.5a: Fetch User's Active Jira Issues

Call `jira_search` with:
```
assignee = currentUser() AND status NOT IN (Done, Closed, Resolved) ORDER BY updated DESC
```

This gives a list of the user's currently active Jira issues with their summaries.

If `~/.punch/prefs.json` has `default_projects`, also include:
```
project IN (PROJ, TEAM) AND assignee = currentUser() AND status NOT IN (Done, Closed, Resolved)
```

### 5.5b: Keyword Matching

For each unlinked activity, extract keywords from:
- Commit messages (stripped of conventional commit prefixes like `feat:`, `fix:`)
- MR titles
- Branch names (split on `/`, `-`, `_`)

Compare these keywords against Jira issue summaries using simple overlap scoring:
- Count matching words (case-insensitive, ignoring stop words)
- Score = matching words / total keywords
- Threshold: score ≥ 0.3 → suggest as a match

### 5.5c: Present Suggestions

```
  ■ Unlinked Activity — Jira 키 미감지 항목
  │
  │  활성 Jira 이슈:
  │  PROJ-101  드롭다운 UI 개선
  │  PROJ-205  인증 모듈 리팩토링
  │  PROJ-310  성능 튜닝
  │  TEAM-42   README 문서 정리
  │
  ├─ 1  "fix dropdown alignment" (3 commits)
  │     → PROJ-101 드롭다운 UI 개선?
  │
  ├─ 2  "refactor auth module" (MR !38)
  │     → PROJ-205 인증 모듈 리팩토링?
  │
  ├─ 3  "update README" (1 commit)
  │     → TEAM-42 README 문서 정리?
  │
  └─ 4  "cleanup CI pipeline" (1 commit)
        (추천 없음)

  확인/수정해주세요.
  예: "1번 맞아", "2번 PROJ-310으로", "4번 빼줘"
```

### 5.5d: User Response Handling

- "맞아" / "확인" → accept all suggestions
- "1번 맞아" → accept suggestion for #1
- "2번 PROJ-310으로" → override suggestion with user-specified key
- "4번 빼줘" → exclude from sync
- "전부 빼줘" → exclude all unlinked activity
- Manual entry: "4번 PROJ-999" → assign to specific issue

### 5.5e: Save Mappings

When a user confirms a mapping (e.g., branch `refactor-auth` → `PROJ-205`), save it to `~/.punch/prefs.json` under `branch_mappings`:

```json
{
  "branch_mappings": {
    "refactor-auth": "PROJ-205",
    "fix-dropdown": "PROJ-101"
  }
}
```

On future runs, check `branch_mappings` first before keyword matching. This learns the user's patterns over time.

---

## Step 6: Fetch Current Jira Issue States

For each unique issue key (both auto-detected and user-confirmed), call `jira_get_issue` to get:
- Current status (e.g., `To Do`, `In Progress`, `In Review`, `Done`)
- Available transitions (call `jira_get_transitions`)
- Existing worklogs for today (for dedup)

This data is needed for both worklog dedup and issue update proposals.

---

## Step 7: Learn Worklog Style

Same as `/punch:sync-worklog` Step 7:
1. Collect user's recent worklog comments (5-10 entries)
2. Analyze language, format, detail level, prefix, references
3. Show detected style and confirm
4. Load from `~/.punch/prefs.json` if previously saved

---

## Step 8: Build the Unified Preview

This is the core of `/punch:sync`. Build **three sections** from the activity:

### Section A: Worklogs

Same logic as `/punch:sync-worklog`:
- Estimate time per issue using activity-based strategy
- Check for existing worklogs (dedup)
- Generate comments in learned style

### Section B: Issue Updates (Status Transitions)

**Transition rules — propose status changes based on GitLab events:**

| GitLab Event | Current Status | Proposed Status | Condition |
|-------------|---------------|-----------------|-----------|
| Branch created for issue | `To Do` / `Open` | → `In Progress` | Branch name contains issue key |
| First commit on issue | `To Do` / `Open` | → `In Progress` | No prior commits for this issue today |
| MR created | `In Progress` | → `In Review` | MR title/branch contains issue key |
| MR merged | `In Review` / `In Progress` | → `Done` | MR title/branch contains issue key |
| Issue closed (GitLab) | any | → `Done` | GitLab issue linked to Jira key |

**Safety rules:**
- NEVER propose a backward transition (e.g., `Done` → `In Progress`) unless explicitly detected
- NEVER propose a transition if the current status already matches or is further along
- Only propose transitions that are **available** in `jira_get_transitions` response
- If the target status name doesn't exactly match (teams customize), use fuzzy matching:
  - `Done` ≈ `완료` ≈ `Closed` ≈ `Resolved`
  - `In Progress` ≈ `진행 중` ≈ `Working`
  - `In Review` ≈ `리뷰 중` ≈ `Code Review` ≈ `Review`
  - `To Do` ≈ `할 일` ≈ `Open` ≈ `Backlog`

**If no valid transition exists** for a proposed status change, skip it silently.

### Section C: Issue Comments

**Comment rules — add informational comments to Jira issues:**

| GitLab Event | Comment Content |
|-------------|----------------|
| MR created | `"MR !42 created: [title] (+230/-45, 5 commits)"` |
| MR merged | `"MR !42 merged by [author] → [target_branch]"` |
| Code review given | `"Code review: 3 comments on MR !45"` |

**Comment style:** Follow the same style detected in Step 7 (language, detail level).

**When NOT to comment:**
- Don't add comments for individual commits (too noisy)
- Don't comment if there's already a similar comment today (check with `jira_get_issue` comments)
- Don't comment on "Issue Activity" that originated from Jira itself (avoid loops)

---

## Step 9: Present Unified Preview

**CRITICAL: This is the approval gate. Do NOT call any Jira write API before this step.**

```
╭─────────────────────────────────────────────╮
│   ⚡ Punch Sync — 2026-03-12                 │
╰─────────────────────────────────────────────╯

  ■ Worklogs
  │
  ├─ 1  PROJ-101   3h 45m   5 commits, MR !42 merged
  │     "Dashboard 위젯 구현 및 MR !42 머지"
  │
  ├─ 2  PROJ-205   1h 30m   2 commits
  │     "API 응답 처리 수정"
  │
  └─ 3  PROJ-310   15m      1 issue comment
        "성능 튜닝 이슈 코멘트"

  ■ Issue Updates
  │
  ├─ 4  PROJ-101   In Progress → Done        MR !42 merged
  └─ 5  PROJ-310   To Do → In Progress       branch created

  ■ Comments
  │
  ├─ 6  PROJ-101   MR !42 merged → main (+230/-45)
  └─ 7  PROJ-205   MR !38 created: API 응답 처리 수정

╭─────────────────────────────────────────────╮
│  3 worklogs · 2 transitions · 2 comments    │
│  Total: 5h 30m                              │
╰─────────────────────────────────────────────╯

  ⚠ PROJ-101: 이미 오늘 2h 워크로그 있음 (중복 가능)

  이대로 진행할까요? 번호로 수정/제외 가능합니다.
```

### User Interaction Options

- **Approve all**: "확인", "ㅇㅇ", "yes" → execute all
- **Approve section**: "워크로그만", "이슈 업데이트만", "코멘트 빼줘" → selective sections
- **Modify entry**: "1번 2시간으로", "#5 빼줘" → adjust and re-display
- **Edit comment**: "6번 코멘트 수정" → let user edit
- **Worklog only**: "워크로그만 해줘" → equivalent to `/punch:sync-worklog`
- **Cancel**: "취소" → abort entirely

**NEVER call any Jira write API without explicit approval.**

---

## Step 10: Execute

Execute in order: **Status transitions → Comments → Worklogs**

(Status first because a transition might fail if the issue is in the wrong state, and you want to know before logging time.)

### 10a: Issue Status Transitions

For each approved transition, call `jira_transition_issue`:
- `issue_key`: the Jira issue key
- `transition_id`: from `jira_get_transitions` (matched by target status name)

```
  ■ Executing — Issue Updates
  │
  ├─ PROJ-101   In Progress → Done        ● done
  └─ PROJ-310   To Do → In Progress       ● done
```

If a transition fails (e.g., required field missing), report the error and continue.

### 10b: Jira Comments

For each approved comment, call `jira_add_comment`:
- `issue_key`: the Jira issue key
- `body`: the comment text

```
  ■ Executing — Comments
  │
  ├─ PROJ-101   MR !42 merged             ● done
  └─ PROJ-205   MR !38 created            ● done
```

### 10c: Worklogs

For each approved worklog, call `jira_add_worklog`:
- `issue_key`: the Jira issue key
- `time_spent`: Jira format (`3h 45m`)
- `started`: ISO 8601 with timezone
- `comment`: in learned style

```
  ■ Executing — Worklogs
  │
  ├─ PROJ-101   3h 45m                    ● done
  ├─ PROJ-205   1h 30m                    ● done
  └─ PROJ-310   15m                       ● done
```

---

## Step 11: Save History

Save to `~/.punch/history.json`:

```json
{
  "syncs": [
    {
      "date": "2026-03-12",
      "synced_at": "2026-03-12T18:30:00+09:00",
      "worklogs": [
        { "issue": "PROJ-101", "time": "3h 45m" },
        { "issue": "PROJ-205", "time": "1h 30m" }
      ],
      "transitions": [
        { "issue": "PROJ-101", "from": "In Progress", "to": "Done" }
      ],
      "comments": [
        { "issue": "PROJ-101", "type": "mr_merged" }
      ],
      "total_time": "5h 30m"
    }
  ]
}
```

Check history on future runs to detect already-synced dates.

---

## Step 12: Summary

```
╭─────────────────────────────────────────────╮
│   ✓ Punch — Complete                        │
╰─────────────────────────────────────────────╯

  ■ Results
  │
  ├─ Worklogs      3 entries, 5h 30m total
  ├─ Transitions   PROJ-101 → Done
  │                PROJ-310 → In Progress
  ├─ Comments      2 added
  └─ History       ~/.punch/history.json

  Tip: /punch:worklog-report today 로 확인
```

---

## Preferences

Users can configure default behavior in `~/.punch/prefs.json`:

```json
{
  "sync_sections": {
    "worklogs": true,
    "transitions": true,
    "comments": true
  },
  "transition_rules": {
    "mr_merged_to": "Done",
    "mr_created_to": "In Review",
    "branch_created_to": "In Progress"
  },
  "comment_on_mr_created": true,
  "comment_on_mr_merged": true,
  "comment_on_review": false,
  "style_profile": { "lang": "ko", "format": "freetext", "detail": "moderate" },
  "default_strategy": "A",
  "timezone": "+09:00"
}
```

On first run, all sections are enabled. The user can disable sections globally or per-run.

---

## Error Handling

- GitLab MCP not configured → guide to `/punch:setup`
- Jira MCP not configured → offer dry-run (show preview without writing)
- Transition not available → skip with warning, don't block other operations
- Comment API error → report, continue
- Worklog API error → report, continue
- Never silently skip errors
- If ALL operations fail → suggest checking MCP configuration
