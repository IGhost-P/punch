---
name: worklog-report
description: "View existing Jira worklogs and detect duplicates"
---

# /punch:worklog-report

Help the user review their existing Jira worklogs.

## Usage

```
/punch:worklog-report PROJ-101
/punch:worklog-report today
/punch:worklog-report this-week
```

**Trigger keywords:** "오늘 기록 확인", "워크로그 확인", "얼마나 기록했지", "what did I log", "show my worklogs"

---

## Pre-flight: Tool Detection

Detect Jira tools (same as `/punch:sync` — tool-agnostic, any source).

```
╭─────────────────────────────────────────────╮
│   ⚡ Punch Worklog Report                    │
╰─────────────────────────────────────────────╯

  ■ Connections
  │
  └─ Jira     🟢 ready     via Confluence MCP
```

- OK → proceed
- Missing → guide to `/punch:setup`
- If `~/.punch/history.json` exists, offer offline mode

---

## Arguments

- **Issue key** (e.g., `PROJ-101`) → show worklogs for that issue
- **`today`** (default) → all worklogs logged today
- **`this-week`** → worklogs for the current week

---

## Mode 1: Single Issue

1. Call `jira_get_worklog` for the issue.
2. Filter entries by the current user.
3. Display:

```
  ■ Worklogs for PROJ-101
  │
  ├─ 2026-03-12   3h      Dashboard 위젯 구현 및 MR !42 머지
  ├─ 2026-03-11   2h      SVG viewport 줌/패닝 개선
  └─ Total         5h

  Source: Jira API
```

---

## Mode 2: Daily/Weekly Summary

1. Detect Jira project keys from recent git branches, or ask the user.
2. Use `jira_search` with JQL:
   ```
   worklogAuthor = currentUser() AND worklogDate >= "YYYY-MM-DD"
   ```

3. For each found issue, fetch worklogs filtered by date and user.
4. Display:

```
╭─────────────────────────────────────────────╮
│   ⚡ Worklog Summary — 2026-03-12            │
╰─────────────────────────────────────────────╯

  ■ Entries
  │
  ├─ PROJ-101   3h      Dashboard 위젯 구현
  ├─ PROJ-205   1h 30m  API 응답 처리 수정
  └─ Total       4h 30m

  ■ Daily Stats
  │
  ├─ Logged      4h 30m
  ├─ Remaining   3h 30m  (8h 기준)
  └─ Coverage    56%

  Tip: /punch:sync-worklog today 로 나머지 채우기
```

### Weekly View (this-week)

For weekly reports, show a day-by-day breakdown:

```
╭─────────────────────────────────────────────╮
│   ⚡ Weekly Summary — 03-10 ~ 03-12          │
╰─────────────────────────────────────────────╯

  ■ Daily Breakdown
  │
  ├─ Mon 03-10   7h 30m / 8h   ▰▰▰▰▰▰▰▰▰▱  94%
  ├─ Tue 03-11   8h / 8h       ▰▰▰▰▰▰▰▰▰▰  100%
  └─ Wed 03-12   4h 30m / 8h   ▰▰▰▰▰▱▱▱▱▱  56%

  ■ Total
  │
  ├─ Logged   20h / 24h
  └─ Gap      4h 부족

  Issues: PROJ-101, PROJ-205, PROJ-310, PROJ-415
```

---

## Duplicate Detection

Flag entries that look like duplicates:

- Same issue + same date + similar time = likely duplicate
- Multiple "Punch:" entries on same issue+date = likely re-sync
- Warn: `⚠️ PROJ-101: 오늘 3h 워크로그가 2건 있습니다 (중복 가능)`

---

## Offline Mode (Fallback)

When Jira MCP is unavailable but `~/.punch/history.json` exists:

```
  ■ Offline Report (cached)
  │
  │  ⚠ Jira 연결 불가 — 로컬 이력 표시
  │
  ├─ Last sync    2026-03-12 18:30
  ├─ PROJ-101     3h 45m
  └─ PROJ-205     1h 30m

  Source: ~/.punch/history.json
```

---

## Error Handling

- Jira MCP not configured → guide to `/punch:setup`, offer offline mode
- JQL returns no results → suggest broader date range
- API errors → report clearly, fall back to cached data if available