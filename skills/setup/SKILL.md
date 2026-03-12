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

**Detect first, install only if needed. Official plugin pattern: `plugin.json` mcpServers + shell env vars.**

Punch declares MCP servers in `plugin.json` using `${ENV_VAR}` placeholders in the `env` block — this is the official Claude Code plugin pattern (confirmed working in v2.0.72+, see [anthropics/claude-code#9427](https://github.com/anthropics/claude-code/issues/9427)).

**How it works:**
1. `plugin.json` declares `mcpServers` with `"env": { "JIRA_URL": "${JIRA_URL}" }` — the `env` block resolves shell environment variables
2. The user must have `GITLAB_URL`, `GITLAB_TOKEN`, `JIRA_URL`, `JIRA_PERSONAL_TOKEN` set in their shell environment
3. `/punch:setup` collects credentials and writes them to `~/.zshenv` (NOT `~/.zshrc` — `~/.zshenv` is sourced for ALL zsh instances including non-interactive shells used by Claude Code)

**For Cursor users:** Plugin `mcpServers` don't apply in Cursor. Setup writes directly to `~/.cursor/mcp.json` with actual values.

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

Determine where to write config. **Strategy differs by runtime.**

| Runtime         | Plugin MCP auto-loaded? | Setup action                                          |
|-----------------|------------------------|-------------------------------------------------------|
| **Claude Code** | Yes (plugin.json)      | Write env vars to `~/.zshenv` → restart Claude Code  |
| **Cursor**      | No                     | Write actual values to `~/.cursor/mcp.json`           |

**CRITICAL RULES:**
- In **Claude Code**: The plugin's `mcpServers` in `plugin.json` auto-load with `${ENV_VAR}` resolution from the `env` block. So the setup only needs to ensure the env vars are SET. Try writing to **`~/.zshenv`** first (sourced for ALL zsh instances). If not writable (e.g., root-owned on managed machines), fall back to **`~/.zprofile`** (sourced for login shells — covers Claude Code CLI started from a terminal). Do NOT rely on `~/.zshrc` alone — it's only for interactive shells.
- In **Cursor**: Plugin `mcpServers` don't apply. Write directly to `~/.cursor/mcp.json` using `Read` + `Write` tools with actual credential values.
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

#### 2d: AUTO-REGISTER

**This is the critical step. The agent MUST directly modify the config, not just show instructions.**

---

**Path A — Claude Code (plugin mcpServers auto-loaded):**

The plugin's `plugin.json` already declares `mcpServers` with `${ENV_VAR}` in `env` blocks. Claude Code resolves these from the shell environment. So setup only needs to **set the env vars**.

1. Try writing to `~/.zshenv` first. If permission denied (e.g., root-owned), use `~/.zprofile` instead.
2. Check if `GITLAB_URL`, `GITLAB_TOKEN`, `JIRA_URL`, `JIRA_PERSONAL_TOKEN` are already exported in the target file
3. Append missing exports:

```bash
# Punch — GitLab & Jira credentials (for Claude Code plugin MCP)
export GITLAB_URL="<collected-url>"
export GITLAB_TOKEN="<collected-token>"
export JIRA_URL="<collected-url>"
export JIRA_PERSONAL_TOKEN="<collected-token>"
```

4. Tell user to restart Claude Code (`/exit` then re-launch `claude`)

**Shell config file priority:**

| File | Sourced when | Best for |
|------|-------------|----------|
| `~/.zshenv` | ALL zsh instances | Preferred (but may be root-owned) |
| `~/.zprofile` | Login shells | Fallback — covers `claude` CLI started from terminal |
| `~/.zshrc` | Interactive shells only | NOT reliable for MCP server processes |

---

**Path B — Cursor (write actual values to mcp.json):**

Plugin `mcpServers` don't apply in Cursor. Write directly to `~/.cursor/mcp.json`:

1. Read the existing `~/.cursor/mcp.json` file
2. Parse the JSON
3. Add the missing server(s) to `mcpServers`:

GitLab:

```json
{
  "gitlab": {
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
6. Tell user to reload Cursor (Cmd+Shift+P → "Reload Window")

---

**IMPORTANT RULES (both paths):**
- NEVER overwrite existing servers
- NEVER remove other MCP servers from the config
- NEVER use `npx` — always use `uvx` for local processes
- ALWAYS use `Read` tool to get current file content first
- For `~/.zshenv`: only append, never overwrite existing exports
- For `~/.cursor/mcp.json`: if file doesn't exist, create with `{ "mcpServers": { ... } }`

#### 2e: Show Result

**Claude Code:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  환경변수 등록 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ~/.zshenv 에 추가됨:
  ├─ GITLAB_URL           https://gitlab.example.com
  ├─ GITLAB_TOKEN         ****
  ├─ JIRA_URL             https://jira.example.com
  └─ JIRA_PERSONAL_TOKEN  ****

  다음 단계: Claude Code를 재시작하세요.
  /exit → claude 다시 실행
  
  재시작 후 Punch 플러그인의 MCP 서버가 자동으로 연결됩니다.
```

**Cursor:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MCP 서버 등록 완료
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  GitLab   [✓] ~/.cursor/mcp.json 에 추가됨
  Jira     [-] 이미 존재 (mcp-atlassian)

  Cursor를 재시작해야 새 MCP 서버가 활성화됩니다.
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

**Check 3: Environment Variables**

```bash
echo "GITLAB_URL=${GITLAB_URL:-NOT_SET}"
echo "GITLAB_TOKEN=${GITLAB_TOKEN:+SET}"
echo "JIRA_URL=${JIRA_URL:-NOT_SET}"
echo "JIRA_PERSONAL_TOKEN=${JIRA_PERSONAL_TOKEN:+SET}"
```

```
  Environment Variables:
  GITLAB_URL              [✓] https://gitlab.example.com
  GITLAB_TOKEN            [✓] set
  JIRA_URL                [✓] https://jira.example.com
  JIRA_PERSONAL_TOKEN     [✓] set
```

If any are NOT_SET, check `~/.zshenv` for the exports.

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
  env vars 미설정 → /punch:setup 으로 ~/.zshenv 에 추가
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
