---
name: help
description: "Quick reference for all Punch commands"
---

# /punch:help

Display the full command reference for Punch.

**Trigger keywords:** "punch help", "punch 도움말", "뭐 할 수 있어", "어떤 명령어 있어"

## Instructions

When the user invokes this skill, display the following reference:

```
╭─────────────────────────────────────────────╮
│                                             │
│   ⚡ Punch                                   │
│   Clock in your dev work                    │
│                                             │
│   GitLab 활동을 읽고 → Jira를 업데이트      │
│   워크로그, 이슈 상태, 코멘트               │
│   전부 확인 후에만 저장됩니다               │
│                                             │
╰─────────────────────────────────────────────╯

  ■ Commands
  │
  ├─ /punch:sync             전체 동기화
  │                          워크로그 + 이슈 상태 + 코멘트
  │
  ├─ /punch:sync-worklog     워크로그(시간 기록)만
  │
  ├─ /punch:worklog-report   기존 워크로그 조회 + 중복 검사
  │
  ├─ /punch:setup            도구 감지 또는 GitLab + Jira 연결
  │
  └─ /punch:help             이 도움말

  ■ Quick Start
  │
  ├─ /punch:sync today             오늘 하루 정리 (추천)
  ├─ /punch:sync this-week         이번 주 전체
  ├─ /punch:sync-worklog today     워크로그만 기록
  └─ /punch:worklog-report today   기록 확인

  ■ /punch:sync 이 하는 일
  │
  ├─ Worklogs      커밋, MR, 리뷰 기반 시간 기록
  ├─ Transitions   MR 머지 → Done, 브랜치 → In Progress
  └─ Comments      MR 생성/머지 정보를 이슈에 코멘트
  
  전부 한 화면에 프리뷰 → 번호로 선택/수정/제외

  ■ Features
  │
  ├─ Zero-Config     기존 GitLab/Jira 도구 자동 감지
  ├─ Style Learning  기존 워크로그 양식 학습 → 동일 스타일 작성
  ├─ Smart Match     Jira 키 없는 커밋도 활성 이슈와 매칭
  ├─ Dedup           이미 기록된 내용 자동 감지
  ├─ Dry Run         Jira 없이도 GitLab 활동 리뷰 가능
  └─ History         ~/.punch/history.json 에 이력 저장

  ■ 자연어 트리거
  │
  ├─ "오늘 정리해줘"       → /punch:sync today
  ├─ "워크로그만 기록"     → /punch:sync-worklog today
  ├─ "이번 주 기록 확인"   → /punch:worklog-report this-week
  └─ "punch in"            → /punch:sync today

  ■ Config
  │
  ├─ ~/.punch/prefs.json     사용자 선호도 (스타일, 전략, 규칙)
  └─ ~/.punch/history.json   동기화 이력

  설정 초기화: /punch:setup --uninstall
```
