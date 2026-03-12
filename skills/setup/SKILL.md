---
name: setup
description: "Interactive setup wizard for Punch — detect or connect GitLab and Jira"
---

# /punch:setup

Guided onboarding that connects your GitLab and Jira accounts.

## Usage

```
/punch:setup
/punch:setup --diagnose
/punch:setup --uninstall
```

**Trigger keywords:** "punch 설정", "setup punch", "GitLab이랑 Jira 연결해줘"

---

## Design Principle

**Detect first, install only if needed.**

Punch doesn't bundle MCP servers. It uses whatever GitLab/Jira tools are already available — from Cursor MCP, Claude Code MCP, IDE plugins, or any source. If nothing exists, it guides installation.

---

## Setup Wizard Flow

### Step 0: Welcome

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Setup
  Clock in your dev work
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  We'll check two connections:

    1 ─ GitLab   read commits, MRs, reviews
    2 ─ Jira     write worklogs, update issues

  Checking what's already available...
```

---

### Step 1: Detect Existing Tools (Multi-Layer)

**This is the most important step. Use ALL THREE layers to detect tools BEFORE asking for tokens.**

Detection runs top-to-bottom. The first layer that succeeds determines the status.

#### Layer 1 — Direct Tool Call (highest confidence)

Actually call a read-only tool. If it returns data, the tool is **ready**.

| Service | Try calling (in order)                                                      |
|---------|-----------------------------------------------------------------------------|
| GitLab  | `list_projects`, `get_project`, any tool with `gitlab` + read capability    |
| Jira    | `jira_get_all_projects`, `jira_search` with `assignee = currentUser()`, any tool with `jira` + read capability |

**Tool name patterns to try (both environments):**

| Pattern                                          | Environment     |
|--------------------------------------------------|-----------------|
| `mcp__gitlab__*`, `mcp__punch-gitlab__*`         | Claude Code MCP |
| `user-*gitlab*`, any tool containing `gitlab`    | Cursor/IDE MCP  |
| `mcp__jira__*`, `mcp__punch-jira__*`             | Claude Code MCP |
| `user-Confluence-jira_*`, `user-*jira*`          | Cursor/IDE MCP  |

If a tool call succeeds with real data → status = `[✓] ready`.

#### Layer 2 — Config File Scan (medium confidence)

If Layer 1 found nothing, **read the MCP config files** to check if tools are registered but not yet connected (e.g., Cursor needs restart).

**MUST read ALL of these files** (use `Read` tool, ignore errors for missing files):

| File                   | What to look for                                                              |
|------------------------|-------------------------------------------------------------------------------|
| `~/.cursor/mcp.json`  | Keys containing `gitlab`, `GitLab` → GitLab registered in Cursor             |
|                        | Keys containing `jira`, `Jira`, `atlassian`, `Confluence` → Jira in Cursor   |
| `~/.claude/mcp.json`  | Same patterns → registered in Claude Code global                              |
| `~/.claude.json`      | Under `projects.*.mcpServers` → registered in Claude Code project scope       |

**How to scan:** Read the file → parse the JSON → check if any key in `mcpServers` matches the service name (case-insensitive substring match).

If found in config but Layer 1 call failed → status = `[~] registered, not connected`.

**IMPORTANT:** Also note WHICH file and WHICH key name it was found under, for the display.

#### Layer 3 — Not Found

If neither Layer 1 nor Layer 2 found anything → status = `[-] missing`.

#### Display Results

Three possible statuses per service:

| Status | Meaning                              | Display                                    |
|--------|--------------------------------------|--------------------------------------------|
| ready  | Tool call succeeded                  | `[✓] ready     via {source}`               |
| registered | Found in config, not callable    | `[~] registered  in {config_file} ({key})` |
| missing | Not found anywhere                  | `[-] missing`                              |

**Example — Both ready:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Setup — Tool Detection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [✓] ready       via Cursor GitLab plugin
  Jira     [✓] ready       via Confluence MCP

  Both tools available — no setup needed!
```

→ Skip to **Step 4 (Verification)**.

**Example — Registered but not connected:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Setup — Tool Detection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [~] registered   in ~/.cursor/mcp.json (GitLab)
  Jira     [~] registered   in ~/.cursor/mcp.json (Confluence)

  도구가 등록되어 있지만 아직 연결되지 않았습니다.
  Cursor 재시작이 필요할 수 있습니다: Cmd+Shift+P → "Reload Window"
```

→ Ask user to reload, then re-run Layer 1. If still not working → **Step 3 (Troubleshooting)**.

**Example — One or both missing:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Setup — Tool Detection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [✓] ready       via Cursor GitLab plugin
  Jira     [-] missing

  → Jira 도구를 설정해야 합니다.
```

→ Proceed to **Step 2** for the missing tool(s) only.

**Example — Both missing:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Setup — Tool Detection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [-] missing
  Jira     [-] missing

  → 둘 다 설정이 필요합니다. 걱정 마세요, 2분이면 됩니다!
```

→ Proceed to **Step 2**.

**Decision logic:**

| GitLab status | Jira status  | Action                                         |
|---------------|--------------|------------------------------------------------|
| ready         | ready        | → Step 4 (Verification)                        |
| ready         | registered   | → Ask reload, then re-detect Layer 1           |
| registered    | ready        | → Ask reload, then re-detect Layer 1           |
| registered    | registered   | → Ask reload, then re-detect Layer 1           |
| ready         | missing      | → Step 2 (install Jira only)                   |
| missing       | ready        | → Step 2 (install GitLab only)                 |
| missing       | registered   | → Step 2 (install GitLab), ask reload for Jira |
| registered    | missing      | → Ask reload for GitLab, Step 2 for Jira       |
| missing       | missing      | → Step 2 (install both)                        |

---

### Step 2: Auto-Install Missing Tools

**Punch MUST automatically register MCP servers — not just show instructions.**

For each missing tool, collect credentials then write the config directly.

---

#### 2a: Detect Environment

Determine where to write the MCP config. **You MUST write to the correct file for the current runtime.**

| Runtime         | Config File            | How to detect                                      |
|-----------------|------------------------|----------------------------------------------------|
| **Cursor**      | `~/.cursor/mcp.json`   | You have access to `StrReplace`/`Write` file tools |
| **Claude Code** | `~/.claude/mcp.json`   | You are running inside `claude` CLI                |

**CRITICAL RULES:**
- In **Cursor**: Write directly to `~/.cursor/mcp.json` using `Read` + `StrReplace`/`Write` tools. Do NOT use `claude mcp add` — that writes to Claude Code's config which Cursor cannot see.
- In **Claude Code**: Write directly to `~/.claude/mcp.json`. Do NOT rely on `claude mcp add` because it writes to project-scoped config (`~/.claude.json` → `projects → {path} → mcpServers`) which may not persist across projects.
- **NEVER** just show instructions and ask the user to configure manually. Always write the file directly.

---

#### 2b: Collect GitLab Credentials (if GitLab missing)

Ask the user:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  GitLab 연결
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab URL을 알려주세요
  예: https://gitlab.example.com

  Personal Access Token이 필요합니다
  생성: {gitlab_url}/-/user_settings/personal_access_tokens
  스코프: read_api, read_repository

  토큰을 입력해주세요:
```

#### 2c: Collect Jira Credentials (if Jira missing)

Ask the user:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Jira 연결
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Jira URL
  예: https://yourcompany.atlassian.net

  인증 방식
  Cloud: Email + API Token
  Server/DC: Personal Access Token

  정보를 입력해주세요:
```

#### 2d: AUTO-REGISTER — Write directly to MCP config

**This is the critical step. The agent MUST directly modify the config file, not just show instructions.**

**For Cursor (`~/.cursor/mcp.json`):**

1. Read the existing `~/.cursor/mcp.json` file
2. Parse the JSON
3. Add the missing server(s) to `mcpServers`:

```json
{
  "gitlab": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-gitlab"],
    "env": {
      "GITLAB_PERSONAL_ACCESS_TOKEN": "<collected-token>",
      "GITLAB_API_URL": "<collected-url>/api/v4"
    }
  }
}
```

For Jira (if missing — check if `mcp-atlassian` or similar already exists):

```json
{
  "jira": {
    "command": "uvx",
    "args": ["mcp-atlassian"],
    "env": {
      "JIRA_URL": "<collected-url>",
      "JIRA_PERSONAL_TOKEN": "<collected-token>"
    }
  }
}
```

4. Write the updated JSON back to `~/.cursor/mcp.json`
5. Preserve ALL existing servers — only add new ones

**For Claude Code (`~/.claude/mcp.json`):**

Same approach — read, merge, write.

**IMPORTANT RULES:**
- NEVER overwrite existing servers
- NEVER remove other MCP servers from the config
- ALWAYS use `Read` tool to get current file, `JSON.parse`, add new keys, then `Write` tool
- If file doesn't exist, create it with `{ "mcpServers": { ... } }`

#### 2e: Show Result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MCP 서버 등록 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [✓] ~/.cursor/mcp.json 에 추가됨
  Jira     [-] 이미 존재 (mcp-atlassian)

  Cursor를 재시작해야 새 MCP 서버가 활성화됩니다.
  Cmd+Shift+P → "Reload Window" 또는 Cursor 재시작
```

---

### Step 3: Wait for Reload & Re-detect

```
  Cursor를 재시작하셨나요?

    → 완료 (도구 다시 감지)
    → 도움 필요
```

On "완료" → re-run Step 1 detection.

**If tools still not detected after reload:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Troubleshooting
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [✗] GitLab MCP가 아직 감지되지 않습니다

  확인사항:
  1. Cursor 하단 상태바에서 MCP 서버 상태 확인
  2. Cursor Settings → MCP 에서 "gitlab" 서버가 보이는지 확인
  3. 서버가 "Failed" 상태라면 토큰/URL을 다시 확인

  다시 시도하시겠어요? [Yes / No]
```

---

### Step 4: Connection Verification

**Actually call the tools to verify they work.**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Verifying Connections...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   testing API call...
  Jira     testing API call...
```

- **GitLab**: call a read-only tool (list projects, get user)
- **Jira**: call `jira_search` with `assignee = currentUser() ORDER BY updated DESC`

**Success:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch — Ready!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Connections:
  GitLab   [✓] connected   @username
  Jira     [✓] connected   company.atlassian.net

  Quick Start:
  오늘 전체 동기화     /punch:sync today
  워크로그만           /punch:sync-worklog today
  기록 확인            /punch:worklog-report today

  Security:
  토큰은 MCP 설정에 저장됩니다. git에 커밋되지 않습니다.
```

**Failure:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Connection Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [✓] connected
  Jira     [✗] failed     401 Unauthorized

  Jira API 토큰이 만료되었거나 잘못되었을 수 있습니다.
  확인: https://id.atlassian.com/manage-profile/security/api-tokens

  토큰을 다시 입력하시겠어요? [Yes / No]
```

---

## Diagnose Mode (--diagnose)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Diagnostics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Check 1: Available tools**

Scan all available tool namespaces. Report what was found.

```
  Available Tools:
  GitLab   [✓] found      user-gitlab-* (3 tools)
  Jira     [✓] found      user-Confluence-jira_* (40 tools)
  Other    [-] none
```

**Check 2: Connectivity**

Make test calls to each tool.

```
  Connectivity:
  GitLab API   [✓] OK        as @swyang
  Jira API     [✓] OK        company.atlassian.net
```

**Check 3: npx health (only if npx-based MCP servers detected)**

```bash
npx -y --version 2>&1
ls -la ~/.npm/_cacache/ 2>&1 | head -5
npm ping 2>&1
```

```
  npx Health (Claude Code MCP uses npx):
  Node.js       [✓] v20.11.0
  npx           [✓] available
  npm cache     [✗] EACCES
  npm registry  [✓] reachable
```

**Check 4: Summary**

```
  Summary:
  Status:   [✗] 1 issue found
  Cause:    npm 캐시 권한 문제
  Fix:      sudo chown -R $(whoami) ~/.npm

  또는 npx가 불필요한 방법으로 전환하세요:
  /punch:setup 에서 Option A (Cursor MCP) 선택
```

---

## Uninstall (--uninstall)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Uninstall
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  삭제 대상:
  - punch-gitlab MCP 등록 (있는 경우)
  - punch-jira MCP 등록 (있는 경우)

  유지 항목:
  - Jira 워크로그 기록
  - ~/.punch/ 설정 및 히스토리
  - 다른 플러그인의 GitLab/Jira 연결

  진행할까요? [Yes / No]
```

If Yes:

1. Remove `punch-gitlab` and `punch-jira` from MCP config (if they exist)
2. Does NOT touch tools from other sources
3. Confirm: "Punch 설정이 제거되었습니다."
