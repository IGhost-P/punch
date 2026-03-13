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

**Detect first, install only if needed. MCP first, REST API fallback. Never rely on local `git log`.**

### Data Source Priority

| Priority | GitLab source | Jira source | Notes |
|----------|--------------|-------------|-------|
| 1st | MCP tools (`mcp__*gitlab*`, `user-*gitlab*`) | MCP tools (`jira_*`, `user-*jira*`) | Richest integration |
| 2nd | **REST API via `curl`** (URL + token) | — | Always works with token |
| 3rd | ~~Local `git log`~~ | — | **NEVER use.** Does not reflect remote state |

**GitLab REST API** is a first-class fallback, not a last resort. MCP servers frequently error due to process spawning issues. The REST API (`curl -H "PRIVATE-TOKEN: ..." https://gitlab.example.com/api/v4/...`) is 100% reliable when the token is valid.

### Credential Storage

Punch stores credentials in `~/.punch/credentials.json` (gitignored). This file is the single source of truth for both MCP registration AND REST API fallback.

```json
{
  "gitlab": {
    "url": "https://gitlab.example.com",
    "token": "glpat-..."
  },
  "jira": {
    "url": "https://jira.example.com",
    "token": "..."
  }
}
```

### MCP Registration

After collecting credentials, setup also registers MCP servers (best-effort):

| Runtime | Method | Storage |
|---------|--------|---------|
| **Claude Code** | `claude mcp add --scope user` | `~/.claude.json` |
| **Cursor** | Direct file write | `~/.cursor/mcp.json` |

If MCP registration fails or the server errors at runtime, sync falls back to REST API automatically.

**Never use `npx`** — it has widespread EACCES permission issues. Use `uvx` (Python) for MCP servers.

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

**This is the most important step. Use ALL layers to detect tools BEFORE asking for tokens.**

Detection runs top-to-bottom. The first layer that succeeds determines the status.

#### Layer 1 — MCP Tool Call (highest confidence)

Actually call a read-only MCP tool. If it returns data, the tool is **ready via MCP**.

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

If a tool call succeeds with real data → status = `[✓] ready (MCP)`.

#### Layer 2 — REST API Test (GitLab only, high confidence)

If Layer 1 failed for GitLab, check if `~/.punch/credentials.json` or `~/.cursor/mcp.json` has GitLab URL + token. If found, test the REST API directly:

```bash
curl -s --header "PRIVATE-TOKEN: <token>" "<url>/api/v4/user"
```

If the curl returns a valid user JSON → status = `[✓] ready (REST API)`.

**This is a first-class connection method, not a fallback.** GitLab MCP servers frequently error due to `uvx` process spawning issues in Cursor/Claude Code. The REST API is 100% reliable when the token is valid.

#### Layer 3 — Config File Scan (medium confidence)

If Layers 1-2 found nothing, **read the MCP config files** to check if tools are registered but not yet connected.

**MUST read ALL of these files** (use `Read` tool, ignore errors for missing files):

| File                   | What to look for                                                              |
|------------------------|-------------------------------------------------------------------------------|
| `~/.punch/credentials.json` | Punch's own credential store                                            |
| `~/.cursor/mcp.json`  | Keys containing `gitlab`, `GitLab` → GitLab registered in Cursor             |
|                        | Keys containing `jira`, `Jira`, `atlassian`, `Confluence` → Jira in Cursor   |
| `~/.claude.json`       | Under `mcpServers` → registered in Claude Code                               |

If found in config but Layers 1-2 failed → status = `[~] registered, not connected`.

#### Layer 4 — Not Found

If no layer found anything → status = `[-] missing`.

#### Display Results

Four possible statuses per service:

| Status | Meaning                              | Display                                    |
|--------|--------------------------------------|--------------------------------------------|
| ready (MCP) | MCP tool call succeeded         | `[✓] ready     via {MCP source}`           |
| ready (API) | REST API call succeeded         | `[✓] ready     via REST API (@username)`   |
| registered  | Found in config, not callable   | `[~] registered  in {config_file} ({key})` |
| missing     | Not found anywhere              | `[-] missing`                              |

**Example — Both ready (mixed sources):**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Setup — Tool Detection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [✓] ready       via REST API (@swYang)
  Jira     [✓] ready       via Confluence MCP

  Both tools available!
```

→ Skip to **Step 4 (Verification)**.

**Example — Registered but not connected:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Setup — Tool Detection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [~] registered   in ~/.cursor/mcp.json (GitLab)
  Jira     [~] registered   in ~/.cursor/mcp.json (Confluence)

  MCP 서버가 에러 상태입니다.
  GitLab → REST API로 전환을 시도합니다...
```

→ If GitLab MCP failed, immediately try Layer 2 (REST API) before asking user to do anything.

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

| GitLab status       | Jira status  | Action                                         |
|---------------------|--------------|------------------------------------------------|
| ready (MCP or API)  | ready        | → Step 4 (Verification)                        |
| ready (MCP or API)  | registered   | → Ask reload for Jira, then re-detect          |
| ready (MCP or API)  | missing      | → Step 2 (install Jira only)                   |
| registered          | ready        | → Try REST API for GitLab (Layer 2)            |
| registered          | registered   | → Try REST API for GitLab, ask reload for Jira |
| registered          | missing      | → Try REST API for GitLab, Step 2 for Jira     |
| missing             | ready        | → Step 2 (install GitLab only)                 |
| missing             | missing      | → Step 2 (install both)                        |

**Key rule:** When GitLab MCP is `registered` but errored, ALWAYS try REST API before asking user to reload. REST API works when MCP doesn't.

---

### Step 2: Auto-Install Missing Tools

**Punch MUST automatically register MCP servers — not just show instructions.**

For each missing tool, collect credentials then write the config directly.

---

#### 2a: Detect Environment

Determine the runtime and registration method.

| Runtime         | Registration method                              | Storage                   |
|-----------------|--------------------------------------------------|---------------------------|
| **Claude Code** | `claude mcp add --scope user` (Shell tool)       | `~/.claude.json` (user)   |
| **Cursor**      | Direct file write (`Read` + `Write` tools)       | `~/.cursor/mcp.json`      |

**How to detect which runtime you're in:**
- If you can run `claude --version` via Shell → Claude Code
- If you have `StrReplace`/`Write` tools but no `claude` CLI → Cursor

**CRITICAL RULES:**
- **Claude Code**: Use `claude mcp add` CLI command. This is the official, supported registration path. It stores actual values in `~/.claude.json` (user scope) and handles env var injection correctly.
- **Cursor**: Write directly to `~/.cursor/mcp.json` with actual credential values.
- **NEVER** use `${ENV_VAR}` placeholders anywhere. The `${ENV_VAR}` pattern is unreliable for plugin MCP servers ([#11927](https://github.com/anthropics/claude-code/issues/11927)).
- **NEVER** just show instructions and ask the user to configure manually. Always register directly.

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

#### 2d: AUTO-REGISTER

**Three things happen in order: (1) Save credentials, (2) Register MCP (best-effort), (3) Verify via REST API.**

---

**Step 1 — Save credentials to `~/.punch/credentials.json`**

This is the single source of truth. Both MCP and REST API fallback read from here.

```bash
mkdir -p ~/.punch
```

Write (or merge into existing):

```json
{
  "gitlab": {
    "url": "<collected-url>",
    "token": "<collected-token>"
  },
  "jira": {
    "url": "<collected-url>",
    "token": "<collected-token>"
  }
}
```

**Step 2 — Register MCP servers (best-effort)**

MCP registration may fail (Cursor uvx spawning issues, Claude Code env bugs). That's OK — REST API fallback will cover GitLab.

**Claude Code (use `add-json` — the `-e` flag has parsing bugs):**

```bash
claude mcp add-json -s user punch-gitlab '{"type":"stdio","command":"uvx","args":["mcp-gitlab"],"env":{"GITLAB_URL":"<url>","GITLAB_TOKEN":"<token>"}}'

claude mcp add-json -s user punch-jira '{"type":"stdio","command":"uvx","args":["mcp-atlassian"],"env":{"JIRA_URL":"<url>","JIRA_PERSONAL_TOKEN":"<token>"}}'
```

**Cursor:**

1. Read `~/.cursor/mcp.json` → parse → add `punch-gitlab` and `punch-jira` with actual values → write back
2. Skip if already exists under keys like `Confluence`, `GitLab`, `jira`, `atlassian`

**Step 3 — Verify connection (REST API for GitLab, MCP for Jira)**

```bash
curl -s --header "PRIVATE-TOKEN: <token>" "<url>/api/v4/user"
```

If returns valid user JSON → GitLab is ready regardless of MCP status.

---

**IMPORTANT RULES:**
- **ALWAYS** save to `~/.punch/credentials.json` first — this enables REST API fallback
- **NEVER** use `${ENV_VAR}` placeholders — always use **actual values**
- NEVER overwrite existing MCP servers (check before adding)
- NEVER use `npx` — always use `uvx` for MCP servers
- MCP registration failure is NOT a setup failure — REST API is equally valid
- Server keys are prefixed `punch-` to avoid collisions

#### 2e: Show Result

**Claude Code:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MCP 서버 등록 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  claude mcp add 로 등록됨 (user scope):
  ├─ punch-gitlab       uvx mcp-gitlab
  │    GITLAB_URL       https://gitlab.example.com
  │    GITLAB_TOKEN     ****
  ├─ punch-jira         uvx mcp-atlassian
  │    JIRA_URL         https://jira.example.com
  └─   JIRA_PERSONAL..  ****

  다음 단계: Claude Code를 재시작하세요.
  /exit → claude 다시 실행
```

**Cursor:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MCP 서버 등록 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ~/.cursor/mcp.json 에 추가됨:
  ├─ punch-gitlab       uvx mcp-gitlab
  │    GITLAB_URL       https://gitlab.example.com
  │    GITLAB_TOKEN     ****
  ├─ punch-jira         uvx mcp-atlassian
  │    JIRA_URL         https://jira.example.com
  └─   JIRA_PERSONAL..  ****

  다음 단계: Cursor를 재시작하세요.
  Cmd+Shift+P → "Reload Window"
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

**Check 3: MCP Registration**

In Claude Code, run `claude mcp list` via Shell. In Cursor, read `~/.cursor/mcp.json`.

```
  MCP Registration:
  punch-gitlab            [✓] registered   user scope
  punch-jira              [✓] registered   user scope
```

For Cursor, verify the server entries in `~/.cursor/mcp.json` have non-empty URL and token values (not `${ENV_VAR}` placeholders).

**Check 4: uvx health**

```bash
uvx --version 2>&1
python3 --version 2>&1
```

```
  Runtime Health:
  Python        [✓] v3.12.0
  uvx           [✓] available
  pip           [✓] available
```

**Check 5: Summary**

```
  Summary:
  Status:   [✓] All checks passed
  
  만약 문제가 있다면:
  MCP 미등록 → /punch:setup 으로 자동 등록
  Claude Code → claude mcp add 로 직접 등록도 가능
  uvx 미설치 → pip install uv 또는 https://docs.astral.sh/uv/
  Python 미설치 → brew install python3
```

---

## Uninstall (--uninstall)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Punch Uninstall
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  삭제 대상:
  - gitlab MCP 등록 (punch가 추가한 경우)
  - jira MCP 등록 (punch가 추가한 경우)

  유지 항목:
  - Jira 워크로그 기록
  - ~/.punch/ 설정 및 히스토리
  - 다른 플러그인의 GitLab/Jira 연결

  진행할까요? [Yes / No]
```

If Yes:

1. Remove `gitlab` and `jira` keys from MCP config (only if added by Punch — check `"command": "uvx"` + `"args": ["mcp-gitlab"]` or `"args": ["mcp-atlassian"]`)
2. Does NOT touch tools from other sources (e.g., existing `Confluence` key)
3. Confirm: "Punch 설정이 제거되었습니다."
