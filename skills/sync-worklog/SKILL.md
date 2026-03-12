---
name: sync-worklog
description: "Sync GitLab activity to Jira worklogs only (subset of /punch:sync)"
---

# /punch:sync-worklog

Worklog-only mode. Same as `/punch:sync` but **skips issue status transitions and Jira comments**. Use this when you only want to log time.

For the full experience (worklogs + issue updates + comments), use `/punch:sync` instead.

## Usage

```
/punch:sync-worklog today
/punch:sync-worklog this-week
/punch:sync-worklog 2026-03-10
/punch:sync-worklog 2026-03-10..2026-03-12
```

**Trigger keywords:** "워크로그만", "시간만 기록", "log time only"

---

## Pre-flight: Tool Detection

**Punch is tool-agnostic.** It uses whatever GitLab/Jira tools are available from any source.

Detect tools by trying a lightweight read-only call:

**GitLab** — look for: `mcp__gitlab__*`, `mcp__punch-gitlab__*`, `user-*gitlab*`, or any tool that lists commits/projects.

**Jira** — look for: `mcp__jira__*`, `mcp__punch-jira__*`, `user-Confluence-jira_*`, `user-*jira*`, or any tool named `jira_search`/`jira_add_worklog`.

```
╭─────────────────────────────────────────────╮
│   ⚡ Punch Sync-Worklog                      │
╰─────────────────────────────────────────────╯

  ■ Connections
  │
  ├─ GitLab   🟢 ready     via Cursor plugin
  └─ Jira     🟢 ready     via Confluence MCP
```

- Both OK → proceed
- Tool missing → show with `⚪ missing` and guide to `/punch:setup`
- Auth error → show with `🔴 auth failed` and suggest token check

**Remember the detected tool names** for use in subsequent steps.

**Fallback for partial connectivity:**
If only GitLab is available, offer a "dry run" — show what would be logged without actually writing to Jira.

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

If not in a git repo, use GitLab MCP to list projects. If many, ask the user which to scan.

---

## Step 3: Fetch Activity

Fetch **all** activity types for the user within the date range:

| Category           | Source                                                | What it captures      |
|--------------------|-------------------------------------------------------|-----------------------|
| **Commits**        | `list_commits` or Events API                          | Code pushed           |
| **MR Created**     | Events API (`created` + `merge_request`)              | MR preparation        |
| **MR Merged**      | Events API (`merged`)                                 | Final review + merge  |
| **Code Review**    | MR notes/discussions                                  | Reviewing others' MRs |
| **Issue Activity** | Events API (`created`/`commented`/`closed` + `issue`) | Issue triage          |

Fallback if Events API unavailable:

- `list_merge_requests` filtered by author/reviewer
- `git log --author=<email> --since=<date> --until=<date>`

---

## Step 4: Present Activity Summary

Show what was found and let the user choose what to include:

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

Use **AskUserQuestion** or wait for freeform reply:

- "전부" / "yes" → include all
- "코드 리뷰 빼줘" → exclude code review
- Specific selection → apply

---

## Step 5: Parse Jira Issue Keys

Extract keys from all selected activities:

- Branch names: `feature/PROJ-42-user-settings` → `PROJ-42`
- Commit messages: `PROJ-101: fix layout` → `PROJ-101`
- MR titles: `[PROJ-205] Add feature` → `PROJ-205`
- Issue events: directly from the issue reference

Regex: `[A-Z][A-Z0-9_]+-\d+`

Group unrecognized activity under "Unlinked".

---

## Step 6: Check Existing Worklogs (Dedup)

For each issue key, call `jira_get_worklog`. Flag entries where:

- Same user + same date already exists
- Comment contains `"Punch:"` (previously synced by this plugin)

---

## Step 7: Learn Worklog Style (NEW)

**Before generating worklog comments, learn from the user's existing entries.**

1. From the worklogs fetched in Step 6, collect the user's recent comments (last 5-10 entries across all target issues).
2. If the target issues have no worklogs yet, broaden the search: pick 2-3 issues from the same project and call `jira_get_worklog` on those to find the user's recent entries.
3. Analyze the comment style:

```
  ■ Style Detection
  │
  └─ 기존 워크로그에서 양식을 분석 중...
```

**Style dimensions to detect:**

| Dimension          | Examples                                                                      | Possible values                 |
|--------------------|-------------------------------------------------------------------------------|---------------------------------|
| **Language**       | "커밋 3건", "3 commits"                                                          | Korean / English / Mixed        |
| **Format**         | bullet list, free text, prefix tag                                            | bullets / freetext / tag-prefix |
| **Detail level**   | "작업함" vs "PROJ-101 드롭다운 정렬 수정, 반응형 처리 포함"                                     | minimal / moderate / detailed   |
| **Prefix**         | `[DEV]`, `Punch:`, none                                                       | detected prefix or none         |
| **Time reference** | includes commit count, MR numbers, etc.                                       | with-refs / without-refs        |

4. Build a `style_profile` object:

```
Detected style:
  Language:     Korean
  Format:       freetext
  Detail:       moderate
  Prefix:       none
  References:   includes MR numbers
  Example:      "SVG viewport 줌/패닝 개선 및 엣지 케이스 수정"
```

5. Show the detected style briefly and ask if it looks right:

```
기존 워크로그 스타일을 감지했습니다:
  → 한국어, 간결한 자유 텍스트, MR 번호 포함

이 스타일로 작성할까요? [Yes / 다른 스타일로]
```

- If "Yes" or no response → use detected style
- If "다른 스타일로" → ask for preference or show examples

6. If no existing worklogs found at all (new user), fall back to the default format:
   `"Punch: {activity summary in English}"`

**IMPORTANT:** The learned style applies to the `comment` field in `jira_add_worklog`. All other fields (time_spent, started) remain unchanged.

---

## Step 8: Estimate Time

**Per-activity defaults:**

| Activity               | Default Time                     |
|------------------------|----------------------------------|
| Commit (with interval) | Gap to next commit, capped at 2h |
| Commit (isolated)      | 30m                              |
| MR Created             | 30m                              |
| MR Merged              | 15m                              |
| Code Review comment    | 15m per comment                  |
| Issue comment          | 15m                              |
| Issue created          | 20m                              |
| Issue closed           | 10m                              |

**Strategies:**

- **A (default)**: Activity-based — commit intervals + per-activity estimates
- **B**: User says total hours → distribute by activity weight
- **C**: User enters time per issue manually

Show Strategy A. If user says "좀 다른데" or estimates look off, offer B or C.

---

## Step 9: Present Worklog Preview

**CRITICAL: This is the approval gate. Do NOT call `jira_add_worklog` before this step.**

```
╭─────────────────────────────────────────────╮
│   ⚡ Worklog Preview — 2026-03-12            │
╰─────────────────────────────────────────────╯

  ■ Entries
  │
  ├─ 1  PROJ-101   3h 45m   5 commits, MR !42
  │     "Dashboard 위젯 구현 및 MR !42 머지"
  │
  ├─ 2  PROJ-205   1h 30m   2 commits
  │     "API 응답 처리 수정"
  │
  ├─ 3  PROJ-310   15m      1 issue comment
  │     "성능 튜닝 이슈 코멘트"
  │
  └─ 4  PROJ-415   30m      2 review comments on !45
        "!45 코드 리뷰 (2건)"

╭─────────────────────────────────────────────╮
│  4 entries · Total: 6h                      │
╰─────────────────────────────────────────────╯

  ⚠ PROJ-101: 이미 오늘 2h 워크로그 있음 (중복 가능)

  이대로 기록할까요? 번호로 수정/제외 가능합니다.
```

Wait for user response:

- **Approve**: "확인", "ㅇㅇ", "yes", "좋아" → proceed to Step 10
- **Modify**: "1번 2시간으로", "#2 → 1h" → update and re-display
- **Skip**: "3번 빼줘", "unlinked 제외" → remove and re-display
- **Edit comment**: "2번 코멘트 수정해줘" → let user edit the comment text
- **Cancel**: "취소", "cancel" → abort entirely

**NEVER call `jira_add_worklog` without explicit approval.**

---

## Step 10: Record Worklogs

For each approved entry, call `jira_add_worklog`:

- `issue_key`: the Jira issue key
- `time_spent`: confirmed time in Jira format (`3h`, `1h 30m`)
- `started`: target date ISO format (`2026-03-12T09:00:00.000+0900`)
  - If commit timestamps are available, use the first commit time for that issue
- `comment`: generated using the **learned style** from Step 7

Show progress as each entry is recorded:

```
  ■ Recording...
  │
  ├─ PROJ-101   3h 45m   🟢 done
  ├─ PROJ-205   1h 30m   🟢 done
  ├─ PROJ-310   15m      🟢 done
  └─ PROJ-415   30m      🟢 done
```

---

## Step 11: Save Sync History

Save a record of this sync to `~/.punch/history.json` for future dedup and reporting:

```json
{
  "syncs": [
    {
      "date": "2026-03-12",
      "synced_at": "2026-03-12T18:30:00+09:00",
      "entries": [
        { "issue": "PROJ-101", "time": "3h 45m", "activities": 7 },
        { "issue": "PROJ-205", "time": "1h 30m", "activities": 2 }
      ],
      "total": "6h",
      "style_profile": { "lang": "ko", "format": "freetext", "detail": "moderate" }
    }
  ]
}
```

Create `~/.punch/` directory if it doesn't exist.

On subsequent runs, check history first to detect already-synced dates and warn:
```
⚠️  2026-03-12 은 이미 동기화되었습니다 (6h, 4 issues).
다시 동기화하면 중복 워크로그가 생길 수 있습니다.

계속할까요? [Yes / Skip / 다른 날짜로]
```

---

## Step 12: Summary

```
╭─────────────────────────────────────────────╮
│   ✅ Punch — Complete                        │
╰─────────────────────────────────────────────╯

  ■ Results
  │
  ├─ PROJ-101   3h 45m
  ├─ PROJ-205   1h 30m
  ├─ PROJ-310   15m
  └─ PROJ-415   30m
  ─────────────────────
  Total         6h across 4 issues

  ├─ Style      한국어, 자유 텍스트
  └─ History    ~/.punch/history.json

  Tip: /punch:worklog-report today 로 확인
```

---

## User Preferences (Persistent)

Punch stores user preferences in `~/.punch/prefs.json`:

```json
{
  "default_strategy": "A",
  "style_profile": { "lang": "ko", "format": "freetext", "detail": "moderate" },
  "excluded_categories": [],
  "default_projects": ["group/project-name"],
  "timezone": "+09:00"
}
```

On first run, preferences are auto-detected. On subsequent runs, they're loaded and applied. The user can override any preference per-session.

---

## Error Handling

- GitLab MCP not configured → guide to `/punch:setup`
- Jira MCP not configured → same, offer dry-run mode
- Worklog API error → report error, continue with remaining entries
- Network timeout → retry once, then report
- Never silently skip errors