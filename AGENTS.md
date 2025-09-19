# AI Agents Configuration & Guidelines

이 문서는 Tidewave, Claude Code, 그리고 다른 AI 에이전트들이 프로젝트 컨텍스트와 개발 가이드라인을 참조하기 위한 중앙 문서입니다.

## 📋 Project Guidelines

프로젝트의 모든 개발 지침과 규칙은 CLAUDE.md 파일을 참조하세요:

**@./CLAUDE.md**

주요 내용:
- 언어 설정 (한국어 우선)
- Rails 8.0.2 프로젝트 정보
- Turbo-Stimulus-Hotwire 정책
- Git 커밋 & 푸시 규칙
- 진행 상황 문서 관리

### 📚 개발 문서 및 가이드라인

#### Rails 8 & Hotwire 핵심 문서
- **@./docs/RAILS8_SPECIFIC_GUIDE.md** - Rails 8 특화 가이드 ⭐
  - Rails 8의 새로운 기능과 변경사항
  - Hotwire 통합 및 최신 패턴
  - 필수 확인 사항

- **@./docs/rails_hotwire_protocol.md** - Rails Hotwire 구현 프로토콜
  - Turbo Frame/Stream 구현 체크리스트
  - 상태 코드 및 리다이렉션 규칙
  - 검증 및 테스트 절차

- **@./docs/hotwire_playbook.md** - Hotwire 플레이북
  - 실전 구현 패턴
  - 모범 사례 모음
  - 일반적인 시나리오 해결법

- **@./docs/TURBO_STIMULUS_POLICY.md** - Turbo & Stimulus 정책
  - 프로젝트 표준 정책
  - 필수 준수 사항
  - 금지 사항 목록

#### 모범 사례 및 트러블슈팅
- **@./docs/rails8_turbo_stimulus_best_practices.md** - Rails 8 Turbo & Stimulus 모범 사례
- **@./docs/rails8-turbo-best-practices.md** - Turbo 특화 모범 사례
- **@./docs/turbo-stream-troubleshooting.md** - Turbo Stream 트러블슈팅 가이드

#### 프로젝트 특화 가이드
- **@./docs/seed_data_guide.md** - 시드 데이터 가이드
  - 개발/테스트 데이터 구성
  - 시드 데이터 관리 방법

- **@./docs/AI_VALIDATION_GUIDE.md** - AI 검증 가이드
  - AI 에이전트 작업 검증 절차
  - 품질 확인 체크리스트

⚠️ **중요**: Hotwire 관련 작업 시 반드시 위 문서들을 순서대로 확인하세요. 특히 RAILS8_SPECIFIC_GUIDE.md는 최우선으로 참조해야 합니다.

## 🚀 Task Master Guidelines

Task Master AI 워크플로우와 명령어는 다음을 참조하세요:

**@./.taskmaster/CLAUDE.md**

주요 내용:
- Task Master 초기화 및 PRD 파싱
- 일일 개발 워크플로우
- 작업 관리 및 종속성 설정
- MCP 통합 설정

## 🤖 Agent-Specific Configurations

### Tidewave
- **역할**: Rails 개발 도구 및 MCP 서버
- **기능**: 
  - Ruby 코드 실행 (`project_eval`)
  - 데이터베이스 쿼리 실행 (`execute_sql_query`)
  - 로그 분석 (`get_logs`)
  - 소스 코드 위치 찾기 (`get_source_location`)
  - 모델 목록 조회 (`get_models`)
- **연결**: SSE를 통한 MCP 연결 (http://localhost:3000/tidewave/mcp)
- **버전**: 0.2.0

### Claude Code
- **역할**: 메인 개발 에이전트
- **책임**:
  - 모든 프로젝트 규칙과 가이드라인 준수
  - Task Master 작업 진행
  - 코드 작성 및 테스트
  - 문서 업데이트
- **참조 파일**: CLAUDE.md, PROJECT_STRUCTURE.md, DAILY_PROGRESS.md

### Task Master AI
- **역할**: 프로젝트 작업 관리
- **기능**:
  - PRD 문서 파싱
  - 작업 생성 및 관리
  - 복잡도 분석
  - 종속성 관리
- **설정 파일**: .taskmaster/tasks/tasks.json

### Context7
- **역할**: 라이브러리 문서 검색
- **기능**:
  - 최신 라이브러리 문서 검색
  - Rails 8 관련 문서 제공

### Claude Swarm Agents
- **models**: ActiveRecord 모델 전문가
- **controllers**: Rails 컨트롤러 전문가
- **views**: Rails 뷰 및 레이아웃 전문가
- **stimulus**: Stimulus.js 전문가
- **services**: 서비스 객체 전문가
- **jobs**: 백그라운드 작업 전문가
- **tests**: Minitest 테스트 전문가
- **devops**: 배포 및 설정 전문가

## 🔧 MCP Configuration

현재 활성화된 MCP 서버:
```json
{
  "task-master-ai": "stdio transport",
  "tidewave": "SSE transport (http://localhost:3000/tidewave/mcp)",
  "context7": "stdio transport",
  "claude-swarm agents": "stdio transport"
}
```

## 📌 Important Notes

1. **언어 규칙**: 모든 문서와 커밋 메시지는 한국어로 작성
2. **Rails 버전**: Rails 8.0.2 및 Ruby 3.4.5 사용
3. **테스트**: 모든 새 기능에 대한 테스트 필수
4. **문서 업데이트**: 
   - DAILY_PROGRESS.md - 일일 진행 상황
   - PROJECT_STRUCTURE.md - 구조 변경사항
5. **Task Master**: 서브태스크 완료 시 즉시 다음 작업 진행

## 🔗 Quick Links

- [CLAUDE.md](./CLAUDE.md) - 메인 프로젝트 가이드라인
- [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) - 프로젝트 구조 문서
- [DAILY_PROGRESS.md](./DAILY_PROGRESS.md) - 일일 진행 상황
- [.taskmaster/CLAUDE.md](./.taskmaster/CLAUDE.md) - Task Master 가이드
- [.taskmaster/tasks/tasks.json](./.taskmaster/tasks/tasks.json) - 현재 작업 목록