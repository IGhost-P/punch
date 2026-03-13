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

**Detect first, install only if needed. Write actual values — never rely on `${ENV_VAR}` in plugins.**

Punch does NOT bundle `mcpServers` in `plugin.json`. The official `${ENV_VAR}` pattern in plugin MCP configs is **unreliable** — the `env` block is not consistently passed to spawned server processes ([anthropics/claude-code#11927](https://github.com/anthropics/claude-code/issues/11927), open since Nov 2025, 26+ upvotes as of Mar 2026).

**Instead, `/punch:setup` writes actual credential values directly to the user's MCP config file:**

| Runtime | Config file | What setup writes |
|---------|------------|-------------------|
| **Cursor** | `~/.cursor/mcp.json` | Actual URL + token values |
| **Claude Code** | `~/.claude/mcp.json` (user scope) | Actual URL + token values |

**Why not `plugin.json` mcpServers?**
- `${ENV_VAR}` in `env` blocks is NOT reliably resolved for plugin-bundled MCP servers
- Even when resolved, the values may not be passed to spawned processes
- Self-hosted services (GitLab, Jira) have variable URLs per user — can't hardcode
- Community workaround: wrapper scripts — but adds complexity for no benefit

**Detection priority:** Reuse existing tools from any source (IDE plugins, pre-configured MCP) before installing new ones.

**Never use `npx`** — it has widespread EACCES permission issues. Use `uvx` (Python) for local processes.

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

**This is the critical step. The agent MUST directly register MCP servers, not just show instructions.**

---

**Path A — Claude Code (use `claude mcp add` CLI)**

Run these commands via the **Shell** tool. The `claude mcp add` command stores actual values in `~/.claude.json` user scope.

GitLab:

```bash
claude mcp add \
  --scope user \
  --transport stdio \
  --env GITLAB_URL=<collected-url> \
  --env GITLAB_TOKEN=<collected-token> \
  punch-gitlab \
  -- uvx mcp-gitlab
```

Jira:

```bash
claude mcp add \
  --scope user \
  --transport stdio \
  --env JIRA_URL=<collected-url> \
  --env JIRA_PERSONAL_TOKEN=<collected-token> \
  punch-jira \
  -- uvx mcp-atlassian
```

After registration, verify with:

```bash
claude mcp list
```

Tell user to restart Claude Code (`/exit` → re-launch `claude`) for MCP servers to activate.

**Why `--scope user`?** User scope stores in `~/.claude.json` and is available across ALL projects. Local scope (default) only works in the current project.

---

**Path B — Cursor (direct file write)**

1. Read existing `~/.cursor/mcp.json` (ignore error if not exists)
2. Parse JSON (or start with `{ "mcpServers": {} }`)
3. Add missing servers with **actual values**:

GitLab:

```json
{
  "punch-gitlab": {
    "command": "uvx",
    "args": ["mcp-gitlab"],
    "env": {
      "GITLAB_URL": "<collected-url>",
      "GITLAB_TOKEN": "<collected-token>"
    }
  }
}
```

Jira (check if it already exists under keys like `Confluence`, `jira`, `atlassian`):

```json
{
  "punch-jira": {
    "command": "uvx",
    "args": ["mcp-atlassian"],
    "env": {
      "JIRA_URL": "<collected-url>",
      "JIRA_PERSONAL_TOKEN": "<collected-token>"
    }
  }
}
```

4. Write updated JSON back
5. Tell user to reload: `Cmd+Shift+P → "Reload Window"`

---

**IMPORTANT RULES (both paths):**
- **NEVER** use `${ENV_VAR}` placeholders — always use **actual values**
- NEVER overwrite existing servers (check before adding)
- NEVER remove other MCP servers from the config
- NEVER use `npx` — always use `uvx` for local processes
- Server keys are prefixed `punch-` to avoid collisions
- For Cursor: ALWAYS use `Read` tool to get current file content first

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
