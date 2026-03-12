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
╭─────────────────────────────────────────────╮
│                                             │
│   ⚡ Punch Setup                             │
│   Clock in your dev work                    │
│                                             │
╰─────────────────────────────────────────────╯

  We'll check two connections:

    1 ─ GitLab   read commits, MRs, reviews
    2 ─ Jira     write worklogs, update issues

  Checking what's already available...
```

---

### Step 1: Detect Existing Tools

**This is the most important step. Check what the AI agent already has access to BEFORE asking for tokens.**

#### 1a: GitLab Tools

Try these patterns in order:

| Priority | Tool Pattern                                    | Source          |
|----------|-------------------------------------------------|-----------------|
| 1        | `mcp__gitlab__*`, `mcp__punch-gitlab__*`        | Claude Code MCP |
| 2        | `user-*gitlab*`, tools containing `gitlab`      | Cursor/IDE MCP  |
| 3        | Any tool that can `list_commits`, `get_project` | Generic         |

**Test by calling** a read-only tool (e.g., list projects). If it returns data → GitLab is ready.

#### 1b: Jira Tools

Try these patterns in order:

| Priority | Tool Pattern                                     | Source          |
|----------|--------------------------------------------------|-----------------|
| 1        | `mcp__jira__*`, `mcp__punch-jira__*`             | Claude Code MCP |
| 2        | `user-Confluence-jira_*`, `user-*jira*`          | Cursor/IDE MCP  |
| 3        | Any tool named `jira_search`, `jira_add_worklog` | Generic         |

**Test by calling** `jira_search` or `jira_get_all_projects`. If it returns data → Jira is ready.

#### 1c: Display Results

**Case A — Both found:**

```
╭─────────────────────────────────────────────╮
│   ⚡ Punch Setup                             │
╰─────────────────────────────────────────────╯

  ■ Tool Detection
  │
  ├─ GitLab   🟢 ready     via Cursor GitLab plugin
  └─ Jira     🟢 ready     via Confluence MCP

  ✅ Both tools available — no setup needed!
```

→ Skip to **Step 4 (Verification)**.

**Case B — One or both missing:**

```
╭─────────────────────────────────────────────╮
│   ⚡ Punch Setup                             │
╰─────────────────────────────────────────────╯

  ■ Tool Detection
  │
  ├─ GitLab   🟢 ready     via Cursor GitLab plugin
  └─ Jira     ⚪ missing

  → Jira 도구를 설정해야 합니다.
```

→ Proceed to **Step 2** for the missing tool(s).

**Case C — Both missing:**

```
╭─────────────────────────────────────────────╮
│   ⚡ Punch Setup                             │
╰─────────────────────────────────────────────╯

  ■ Tool Detection
  │
  ├─ GitLab   ⚪ missing
  └─ Jira     ⚪ missing

  → 둘 다 설정이 필요합니다. 걱정 마세요, 2분이면 됩니다!
```

→ Proceed to **Step 2**.

---

### Step 2: Install Missing Tools

For each missing tool, ask the user which method they prefer:

```
  ■ Setup Method

  GitLab 도구를 추가하는 방법을 선택해주세요:

    A ─ Cursor MCP 설정에서 추가        ← 권장
        Settings > MCP > Add Server
        npx 없이도 가능

    B ─ Claude Code MCP로 추가
        터미널에서 claude mcp add 실행
        npx 필요

    C ─ 직접 설정할게요
        수동으로 MCP 서버 설정
```

#### Option A: Cursor MCP (Recommended)

First, ask for credentials:

```
  ■ GitLab 정보 입력
  │
  ├─ URL
  │  GitLab 주소를 알려주세요
  │  예: https://gitlab.example.com
  │
  ├─ Token
  │  Personal Access Token이 필요합니다
  │
  │  생성: {gitlab_url}/-/user_settings/personal_access_tokens
  │  스코프: read_api, read_repository
  │
  └─ 토큰을 입력해주세요:
```

Then show the Cursor settings to copy:

```
  ■ Cursor에서 MCP 추가하기
  │
  │  1. Cursor Settings → MCP
  │  2. "Add new MCP server" 클릭
  │  3. 아래 내용으로 설정:
  │
  ├─ Name:     gitlab
  ├─ Type:     command
  ├─ Command:  npx -y @modelcontextprotocol/server-gitlab
  │
  │  Environment Variables:
  ├─ GITLAB_PERSONAL_ACCESS_TOKEN: {입력받은 토큰}
  └─ GITLAB_API_URL: {입력받은 URL}/api/v4
  
  설정 후 Cursor를 재시작해주세요.
  완료되면 알려주세요!
```

Similarly for Jira:

```
  ■ Jira 정보 입력
  │
  ├─ URL
  │  예: https://yourcompany.atlassian.net
  │
  ├─ Email
  │  Jira 계정 이메일
  │
  ├─ Token
  │  생성: https://id.atlassian.com/manage-profile/security/api-tokens
  │
  └─ 토큰을 입력해주세요:
```

```
  ■ Cursor에서 MCP 추가하기
  │
  ├─ Name:     jira
  ├─ Type:     command
  ├─ Command:  npx -y jira-mcp
  │
  │  Environment Variables:
  ├─ JIRA_URL: {입력받은 URL}
  ├─ JIRA_EMAIL: {입력받은 이메일}
  └─ JIRA_API_TOKEN: {입력받은 토큰}
```

#### Option B: Claude Code MCP

**First, check npx prerequisites:**

```bash
npx -y --version 2>&1
```

If npx fails, show specific fix:

```
  ■ npx 사전 점검
  │
  └─ 🔴 문제 발견
  
  {specific error and fix — see table below}
```

| Error                          | Fix                                                       |
|--------------------------------|-----------------------------------------------------------|
| `EACCES` on `~/.npm`           | `sudo chown -R $(whoami) ~/.npm` (터미널에서 실행)               |
| `ENOENT` / `command not found` | `brew install node` (macOS)                               |
| `CERT_HAS_EXPIRED` / `SSL`     | `npm config set strict-ssl false`                         |
| `ETIMEOUT` / `network`         | VPN/프록시 확인                                                |

If npx is OK, register:

```bash
# GitLab
claude mcp add punch-gitlab \
  -e GITLAB_PERSONAL_ACCESS_TOKEN="<token>" \
  -e GITLAB_API_URL="<url>/api/v4" \
  -- npx -y @modelcontextprotocol/server-gitlab

# Jira
claude mcp add punch-jira \
  -e JIRA_URL="<url>" \
  -e JIRA_EMAIL="<email>" \
  -e JIRA_API_TOKEN="<token>" \
  -- npx -y jira-mcp
```

```
  ■ Registration
  │
  ├─ punch-gitlab   🟢 registered
  └─ punch-jira     🟢 registered
```

#### Option C: Manual

```
  ■ 수동 설정 가이드
  │
  │  Punch는 아래 도구가 있으면 동작합니다:
  │
  ├─ GitLab:  list_commits, get_project, list_merge_requests
  └─ Jira:    jira_search, jira_add_worklog, jira_get_issue
  
  어떤 MCP 서버든 위 도구를 제공하면 됩니다.
  설정 완료 후 /punch:setup 으로 확인하세요.
```

---

### Step 3: Wait & Re-detect

If the user configured tools externally (Cursor restart, etc.):

```
  설정을 완료하셨나요?

    → 완료 (도구 다시 감지)
    → 도움 필요
```

On "완료" → re-run Step 1 detection.

---

### Step 4: Connection Verification

**Actually call the tools to verify they work.**

```
  ■ Verifying...
  │
  ├─ GitLab   testing API call...
  └─ Jira     testing API call...
```

- **GitLab**: call a read-only tool (list projects, get user)
- **Jira**: call `jira_search` with `assignee = currentUser() ORDER BY updated DESC`

**Success:**

```
╭─────────────────────────────────────────────╮
│                                             │
│   ⚡ Punch — Ready!                          │
│                                             │
╰─────────────────────────────────────────────╯

  ■ Connections
  │
  ├─ GitLab   🟢 connected   @username
  └─ Jira     🟢 connected   company.atlassian.net

  ■ Quick Start
  │
  ├─ 오늘 전체 동기화     /punch:sync today
  ├─ 워크로그만           /punch:sync-worklog today
  └─ 기록 확인            /punch:worklog-report today

  ■ Security
  │
  └─ 토큰은 MCP 설정에 저장됩니다. git에 커밋되지 않습니다.
```

**Failure:**

```
  ■ Connection Test
  │
  ├─ GitLab   🟢 connected
  └─ Jira     🔴 failed     401 Unauthorized

  Jira API 토큰이 만료되었거나 잘못되었을 수 있습니다.
  확인: https://id.atlassian.com/manage-profile/security/api-tokens

  토큰을 다시 입력하시겠어요? [Yes / No]
```

---

## Diagnose Mode (--diagnose)

```
╭─────────────────────────────────────────────╮
│   🔍 Punch Diagnostics                      │
╰─────────────────────────────────────────────╯
```

**Check 1: Available tools**

Scan all available tool namespaces. Report what was found.

```
  ■ Available Tools
  │
  ├─ GitLab   🟢 found      user-gitlab-* (3 tools)
  ├─ Jira     🟢 found      user-Confluence-jira_* (40 tools)
  └─ Other    ⚪ none
```

**Check 2: Connectivity**

Make test calls to each tool.

```
  ■ Connectivity
  │
  ├─ GitLab API   🟢 OK        as @swyang
  └─ Jira API     🟢 OK        company.atlassian.net
```

**Check 3: npx health (only if npx-based MCP servers detected)**

```bash
npx -y --version 2>&1
ls -la ~/.npm/_cacache/ 2>&1 | head -5
npm ping 2>&1
```

```
  ■ npx Health (Claude Code MCP uses npx)
  │
  ├─ Node.js       🟢 v20.11.0
  ├─ npx           🟢 available
  ├─ npm cache     🔴 EACCES
  └─ npm registry  🟢 reachable
```

**Check 4: Summary**

```
  ■ Summary
  │
  ├─ Status:   🔴 1 issue found
  ├─ Cause:    npm 캐시 권한 문제
  └─ Fix:      sudo chown -R $(whoami) ~/.npm
  
  또는 npx가 불필요한 방법으로 전환하세요:
  /punch:setup 에서 Option A (Cursor MCP) 선택
```

---

## Uninstall (--uninstall)

```
╭─────────────────────────────────────────────╮
│   ⚡ Punch Uninstall                         │
╰─────────────────────────────────────────────╯

  ■ 삭제 대상
  │
  ├─ punch-gitlab MCP 등록 (있는 경우)
  └─ punch-jira MCP 등록 (있는 경우)

  ■ 유지 항목
  │
  ├─ Jira 워크로그 기록
  ├─ ~/.punch/ 설정 및 히스토리
  └─ 다른 플러그인의 GitLab/Jira 연결

  진행할까요? [Yes / No]
```

If Yes:

1. Remove `punch-gitlab` and `punch-jira` from MCP config (if they exist)
2. Does NOT touch tools from other sources
3. Confirm: "Punch 설정이 제거되었습니다."