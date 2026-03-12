<div align="center">

◯ ─────────── ◯
<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/97ae08bd-4ccf-495f-9f9a-e17751d52b6f" />

**P U N C H**

◯ ─────────── ◯

**Clock in your dev work.**

A Claude Code plugin that reads your GitLab activity and syncs it to Jira — worklogs, status transitions, comments. One command. Your approval.

[Quick Start](#quick-start) · [How it Works](#the-flow) · [Commands](#commands) · [Features](#features)

</div>

---

> _Developers shouldn't be timekeepers. Your Git history already knows what you did._

Punch bridges the gap between **where you work** (GitLab) and **where you report** (Jira). It reads your commits, MRs, reviews, and issue activity — then proposes a complete Jira sync. Nothing writes without your explicit OK.

Most developers log worklogs at end-of-day from memory. Punch does it from evidence.

---

## The Flow

```
    GitLab                              Jira

  commits          -->  worklogs
  merge requests   -->  status transitions
  code reviews     -->  comments
  issue activity         |
                         v
                    +-----------+
                    |  PREVIEW  |
                    |  you edit |
                    |  you OK   |
                    +-----------+
```

One preview. Three types of updates. Full control.

```
/punch:sync today
```

**What just happened?**

```
/punch:sync       ->  Fetched 7 commits, 2 MRs, 3 reviews
                  ->  Detected PROJ-101, PROJ-205, PROJ-310
                  ->  Learned your Korean freetext worklog style
                  ->  Proposed 3 worklogs, 2 transitions, 1 comment
                  ->  You approved with "확인"
                  ->  Done. 5h 30m logged across 3 issues.
```

---

## Quick Start

**Step 1 — Install the plugin** (in your terminal):

```bash
claude plugin marketplace add your-org/punch
claude plugin install punch@punch
```

**Step 2 — Run setup** (inside a Claude Code session):

```
/punch:setup
```

> Setup **detects your existing tools first**. Already have GitLab/Jira MCP? Punch uses them as-is — no extra tokens, no extra servers. If tools are missing, setup **automatically registers** them in your MCP config.

**Step 3 — Sync your day:**

```
/punch:sync today
```

---

## Zero-Config Design

Punch doesn't bundle MCP servers. It detects and uses whatever GitLab/Jira tools are already available:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Setup — Tool Detection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [✓] ready     via Cursor GitLab plugin
  Jira     [✓] ready     via Confluence MCP

  Both tools available — no setup needed!
```

If nothing is found, setup **auto-registers** the MCP servers:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MCP 서버 등록 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [✓] ~/.cursor/mcp.json 에 추가됨
  Jira     [-] 이미 존재 (mcp-atlassian)
```

| Source                | GitLab | Jira | npx needed? |
|-----------------------|--------|------|-------------|
| Cursor MCP settings   | ✓      | ✓    | Depends     |
| Claude Code MCP       | ✓      | ✓    | Depends     |
| IDE plugins           | ✓      | —    | No          |
| Cursor Confluence MCP | —      | ✓    | No          |

---

## The Preview

This is what you see before anything is written:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Sync — 2026-03-12
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Worklogs:
  ├─ 1  PROJ-101   3h 45m   5 commits, MR !42 merged
  │     "Dashboard 위젯 구현 및 MR !42 머지"
  │
  ├─ 2  PROJ-205   1h 30m   2 commits
  │     "API 응답 처리 수정"
  │
  └─ 3  PROJ-310   15m      1 issue comment
        "성능 튜닝 이슈 코멘트"

  Issue Updates:
  ├─ 4  PROJ-101   In Progress → Done        MR !42 merged
  └─ 5  PROJ-310   To Do → In Progress       branch created

  Comments:
  └─ 6  PROJ-101   MR !42 merged → main (+230/-45)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  3 worklogs · 2 transitions · 1 comment
  Total: 5h 30m
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  이대로 진행할까요?
```

Your options:

| Input            | What happens                  |
|------------------|-------------------------------|
| "확인" / "yes"   | Execute all                   |
| "1번 2시간으로"  | Adjust time for entry #1      |
| "#5 빼줘"        | Remove entry #5               |
| "워크로그만"     | Execute only worklogs section |
| "코멘트 빼줘"    | Skip all comments             |
| "취소"           | Abort — nothing is written    |

---

## Commands

> All commands run inside a Claude Code session. Run `/punch:setup` after installation to verify tools.

| Command                 | What It Does                                         |
|-------------------------|------------------------------------------------------|
| `/punch:sync`           | Full sync — worklogs + status transitions + comments |
| `/punch:sync-worklog`   | Worklogs only (time logging)                         |
| `/punch:worklog-report` | View existing worklogs + spot duplicates             |
| `/punch:setup`          | Detect tools or connect GitLab + Jira                |
| `/punch:help`           | Full reference                                       |

Natural language triggers:

| Say this              | Runs this                         |
|-----------------------|-----------------------------------|
| "오늘 정리해줘"       | `/punch:sync today`               |
| "워크로그만 기록"     | `/punch:sync-worklog today`       |
| "이번 주 기록 확인"   | `/punch:worklog-report this-week` |
| "punch in"            | `/punch:sync today`               |

---

## Features

### Style Learning

> _Your worklogs should read like you wrote them._

Punch analyzes your recent Jira worklogs and matches the style:

| Dimension      | What it detects                             |
|----------------|---------------------------------------------|
| **Language**   | Korean / English / Mixed                    |
| **Format**     | Bullet list / Free text / Tag prefix        |
| **Detail**     | Minimal ("작업 완료") / Moderate / Detailed |
| **References** | MR numbers, commit counts, line changes     |

Style is saved to `~/.punch/prefs.json` and reused on future runs.

### Issue Transitions

```
  Branch created   -->   To Do → In Progress
  MR created       -->   In Progress → In Review
  MR merged        -->   In Review → Done
  Issue closed     -->   → Done
```

Safety:

- Never proposes backward transitions (`Done` → `In Progress`)
- Only uses transitions available in your Jira workflow
- Handles Korean status names (`진행 중`, `완료`, `리뷰 중`)

### Smart Matching (No Jira Keys? No Problem.)

Not every team puts `PROJ-101` in their commits. Punch handles this:

```
  Unlinked Activity:
  ├─ 1  "fix dropdown alignment" (3 commits)
  │     → PROJ-101 드롭다운 UI 개선?
  │
  ├─ 2  "refactor auth module" (MR !38)
  │     → PROJ-205 인증 모듈 리팩토링?
  │
  └─ 3  "cleanup CI pipeline" (1 commit)
        (추천 없음)
```

Works with any naming convention — or no convention at all. Confirmed mappings are saved and learned for next time.

### Duplicate Prevention

```
  Layer 1: Jira API       기존 워크로그, 코멘트, 상태 확인
  Layer 2: Local history   ~/.punch/history.json
```

### Dry Run

When Jira isn't connected, Punch still works — it shows you the preview without writing.

---

## Safety

```
  Guarantees:
  ├─ Nothing auto-writes       you always confirm
  ├─ Duplicate detection        checks Jira + local history
  ├─ Execution order            transitions → comments → worklogs
  ├─ Dry-run mode               review without writing
  ├─ Error isolation            one failure doesn't block the rest
  └─ No bundled servers         uses your existing tools
```

---

## Setup Requirements

| Service | Token                                                                    | Scopes                        |
|---------|--------------------------------------------------------------------------|-------------------------------|
| GitLab  | Personal Access Token                                                    | `read_api`, `read_repository` |
| Jira    | [API Token](https://id.atlassian.com/manage-profile/security/api-tokens) | default (full access)         |

Run `/punch:setup` — it first checks if you already have GitLab/Jira tools available. If you do, no tokens are needed. If not, it **auto-registers** MCP servers in your config file.

---

## Config

| Path                    | Purpose                                             |
|-------------------------|-----------------------------------------------------|
| `~/.punch/prefs.json`   | Style, strategy, transition rules, default projects |
| `~/.punch/history.json` | Sync history for dedup and offline reports          |

---

## Under the Hood

```
punch/
├── .claude-plugin/
│   ├── plugin.json          Plugin manifest (no bundled MCP)
│   └── marketplace.json     Marketplace distribution
├── .mcp.json.example        Reference MCP config (optional)
├── commands/
│   ├── sync.md              <- main command
│   ├── sync-worklog.md      Worklog-only mode
│   ├── worklog-report.md    Report viewer
│   ├── setup.md             Setup wizard
│   └── help.md              Reference
└── skills/
    ├── sync/                Full sync logic
    ├── sync-worklog/        Worklog-only logic
    ├── worklog-report/      Report logic
    ├── worklog-sync/        Domain knowledge (parsing, estimation)
    ├── setup/               Setup wizard flow
    └── help/                Command reference
```

**Why no bundled MCP?**

Plugins like Ouroboros use `uvx` (Python) — no permission issues. But GitLab/Jira MCP servers use `npx` (Node.js), which hits `npm EACCES` errors when `~/.npm` has root-owned files.

Punch avoids this entirely: it detects tools already in your environment. No `npx`, no npm cache, no permission errors. If you already have GitLab/Jira tools from Cursor or other plugins, Punch just works.

---

_"Your Git history already knows what you did._
_Punch just tells Jira about it."_

`MIT License`
