---
name: worklog-domain
description: "Domain knowledge for Punch — issue key parsing, time estimation, duplicate prevention"
globs:

- "**/*"
---

# Punch Domain Knowledge

Background knowledge for syncing GitLab activity to Jira worklogs. Referenced by other Punch skills.

## Jira Issue Key Parsing

### Pattern

The canonical regex for Jira issue keys:

```
[A-Z][A-Z0-9_]+-\d+
```

Examples: `PROJ-101`, `TEAM-42`, `WEB-7`

### Extraction Sources (priority order)

1. **Branch name**: `feature/PROJ-42-user-settings` → `PROJ-42`
   - Branch names are the most reliable source since they're set once at branch creation.
   - Pattern: look for issue key at the start or after the first `/`.

2. **MR title**: `[PROJ-101] Implement user dashboard` → `PROJ-101`
   - Often contains the key in brackets or as a prefix.

3. **Commit message**: `PROJ-101: fix dropdown alignment` → `PROJ-101`
   - May reference multiple issues; collect all unique keys.
   - Ignore keys that appear in quoted text or URLs (they may be references, not work done).

4. **MR description**: Sometimes contains issue references like `Closes PROJ-101`.

### Deduplication

A single MR may have many commits all referencing the same issue. Deduplicate by:

- Grouping all commits under a branch → single issue key from the branch name
- If branch has no key, fall back to the most frequent key in commit messages

### When No Jira Key Is Found (Smart Matching)

Not all teams embed Jira keys in their Git workflow. When no key is detected:

1. **Check saved mappings** — `~/.punch/prefs.json` → `branch_mappings` may have a known mapping for this branch.
2. **Fetch active Jira issues** — Query `assignee = currentUser() AND status NOT IN (Done, Closed, Resolved)`.
3. **Keyword match** — Extract keywords from commit messages / MR titles / branch names. Compare against Jira issue summaries. Suggest matches with overlap score ≥ 0.3.
4. **User confirms** — Show suggestions in the preview, let the user accept, override, or skip.
5. **Learn** — Save confirmed mappings to `~/.punch/prefs.json` for future runs.

This ensures Punch works regardless of naming conventions — even with zero Jira keys in Git history.

## GitLab Activity Types

Not all GitLab work is commits. The plugin recognizes these activity categories:

| Category          | GitLab Event                           | How to detect                                   | Default time    |
|-------------------|----------------------------------------|-------------------------------------------------|-----------------|
| **Commits/Push**  | `pushed` event or commit list          | `list_commits`, Events API                      | Interval-based  |
| **MR Created**    | `created` + target_type `MergeRequest` | Events API or MR list filtered by created_at    | 30m             |
| **MR Merged**     | `merged` event                         | Events API                                      | 15m             |
| **Code Review**   | `commented` on a MR (note on MR)       | MR notes API, or Events with target_type `Note` | 15m per comment |
| **Issue Comment** | `commented` on an issue                | Events API                                      | 15m             |
| **Issue Created** | `created` + target_type `Issue`        | Events API                                      | 20m             |
| **Issue Closed**  | `closed` + target_type `Issue`         | Events API                                      | 10m             |

### Issue Key Extraction per Activity Type

- **Commits/Push**: From commit message or branch name
- **MR Created/Merged**: From MR title, branch name, or MR description
- **Code Review**: From the target MR's title/branch (the issue you reviewed, not authored)
- **Issue Comment/Created/Closed**: Directly from the issue — if the issue title or body contains a Jira key, use it. Otherwise the GitLab issue itself may not map to Jira.

### Code Review: A Special Case

Code review time is real work but easy to miss. When the user reviews someone else's MR:

- The MR's branch/title may contain a Jira issue key
- Log the review time against that Jira issue
- In the worklog comment, clarify: `"GitLab sync: code review on !45 (2 comments)"`
- This helps distinguish authoring work from review work in Jira

## Time Estimation

### Strategy A: Activity-Based (Default)

**For commits:**

1. Collect all commits by the user within the date range, sorted by timestamp.
2. For consecutive commits on the same issue:
   - Time between them = estimated time spent
   - Cap any single gap at **2 hours** (assume a break occurred)
3. For the first commit of the day:
   - Assume **30 minutes** of ramp-up time before the first commit
4. For isolated commits (only 1 commit for an issue):
   - Estimate **30 minutes** minimum

**For non-commit activities:**

- Apply the default time estimates from the activity type table above.
- Multiple activities on the same issue stack: 3 review comments = 45m.

**Rounding:** Round final per-issue total to nearest 15-minute increment.

### Strategy B: Total Hours Distribution

1. User specifies total hours worked (e.g., 8h).
2. Distribute weighted by total activity count per issue.
3. Round to nearest 15-minute increment.

### Strategy C: Manual Entry

1. Show the issue list.
2. User types time for each one.

Always present Strategy A results first. If the user says the estimates look wrong, offer Strategy B or C.

## Jira Worklog Format

When calling `jira_add_worklog`, use these formats:

- **time_spent**: Jira notation — `1h`, `30m`, `1h 30m`, `2h 15m`
- **started**: ISO 8601 with timezone — `2026-03-12T09:00:00.000+0900`
  - Default to 09:00 local time for the started timestamp
  - If commit timestamps are available, use the first commit time for that issue
- **comment**: Generated using the **learned style** (see below). Default examples:
  - `"Punch: 5 commits, MR !42 created+merged"`
  - `"Punch: code review on !45 (3 comments)"`
  - `"Punch: 1 issue comment, issue closed"`
  - Keep it under 200 characters

## Worklog Style Learning

Before generating comments for new worklogs, Punch analyzes the user's existing worklog entries to match their style.

### How Style Detection Works

1. Collect the user's recent worklog comments (5-10 entries).
2. Analyze across these dimensions:

| Dimension        | What to look for                    | Examples                                                                                      |
|------------------|-------------------------------------|-----------------------------------------------------------------------------------------------|
| **Language**     | Primary language used               | `"작업 완료"` → Korean; `"Fixed bug"` → English                                                   |
| **Format**       | Structure of the comment            | Bullet list, free text, tag prefix                                                            |
| **Detail level** | How much info is included           | `"작업함"` (minimal) vs `"드롭다운 정렬 수정, 반응형 처리 추가"` (detailed)                                     |
| **Prefix**       | Any consistent prefix               | `[DEV]`, `Punch:`, none                                                                       |
| **References**   | Whether MR/commit refs are included | `"MR !42"`, `"3 commits"`                                                                     |

3. Build a style profile and persist it in `~/.punch/prefs.json`.
4. On subsequent runs, load the saved profile. Re-detect every ~10 syncs or when user asks.

### Style Application Rules

- Match the detected language for comment text
- Match the detected format (bullets vs freetext)
- Match the detail level
- Always include `"Punch:"` as a hidden dedup marker within the comment (can be at the end or as a tag)
- Never override user-edited comments

### Fallback (No Existing Worklogs)

If no existing worklogs are found, use the default format:
`"Punch: {concise activity summary in English}"`

## Duplicate Prevention

Before recording any worklog:

1. Fetch existing worklogs for the issue using `jira_get_worklog`.
2. Check if the current user already has an entry for the target date.
3. If a matching entry exists:
   - Show a warning: `⚠️ PROJ-101 already has a 2h worklog for 2026-03-12`
   - Ask: "Do you want to skip, add anyway, or replace the existing entry?"
4. To "replace": there is no update API in most Jira MCPs, so:
   - Warn that the old entry will remain
   - Suggest manually deleting it via Jira UI

### Comment-Based Dedup

Worklogs created by Punch include `"Punch:"` in the comment. Use this marker to detect entries previously created by this plugin and avoid double-counting.

## Common Project Patterns

The user works with these GitLab projects and Jira projects:

- Branch naming: `{type}/{ISSUE-KEY}-{short-description}` (e.g., `feature/PROJ-101-dashboard-widget`)
- Commit format: `{ISSUE-KEY}: {description}` or `{ISSUE-KEY} {description}`
- MR title format: `[{ISSUE-KEY}] {description}` or `{ISSUE-KEY}: {description}`

Adapt parsing to the user's actual conventions once you see their commit history.