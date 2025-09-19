# Claude Code 지침

## 언어 설정
**중요**: 모든 응답, 코드 주석, 커밋 메시지, 문서는 한국어로 작성해야 합니다. 코드 자체(변수명, 함수명 등)는 영어를 사용하되, 설명과 문서는 반드시 한국어로 작성하세요.

## Rails 프로젝트 정보
- **Rails 버전**: 8.0.2
- **Ruby 버전**: 3.4.5
- **프로젝트 타입**: Full-stack Rails
- **데이터베이스**: SQLite (개발/프로덕션 모두)
- **테스트 프레임워크**: Minitest
- **Turbo/Stimulus**: 활성화됨
- **백그라운드 작업**: Solid Queue (Rails 8 내장)

### Rails 개발 가이드라인
- Rails 8의 변경된 규칙을 확인하세요 (Context 7에서 최신 문서 확인)
- Rails 규약과 모범 사례를 따르세요
- 모든 새 기능에 대한 테스트를 작성하세요
- 컨트롤러에서 strong parameters를 사용하세요
- 모델은 단일 책임에 집중하도록 유지하세요
- 복잡한 비즈니스 로직은 서비스 객체로 추출하세요
- 외래 키와 쿼리를 위한 적절한 데이터베이스 인덱싱을 보장하세요

### Turbo-Stimulus-Hotwire 정책

#### 필수 참조 문서
**중요**: Hotwire 관련 작업 시 반드시 다음 문서들을 순서대로 확인:

1. **Rails 8 특화 사항** (최우선)
   - `docs/RAILS8_SPECIFIC_GUIDE.md` - Rails 8 특화 가이드 ⭐

2. **핵심 프로토콜** (필수)
   - `docs/rails_hotwire_protocol.md` - 구현 및 검증 프로토콜
   - `docs/hotwire_playbook.md` - Rails 8 Hotwire 플레이북
   - `docs/TURBO_STIMULUS_POLICY.md` - Turbo & Stimulus 사용 정책

3. **보조 문서** (참고)
   - `docs/rails8_turbo_stimulus_best_practices.md` - 모범 사례
   - `docs/rails8-turbo-best-practices.md` - Turbo 모범 사례
   - `docs/turbo-stream-troubleshooting.md` - 트러블슈팅

#### 작업 시 필수 확인사항
- Rails 8 기본 설정 활용 (Hotwire 내장, importmap 기본)
- status 코드 명시적 지정 (:see_other, :unprocessable_entity)
- turbo:load 이벤트 사용 (DOMContentLoaded 금지)

## 개발 모범 사례
- 기능 사항 개발/수정이 있는 경우, 관련된 시드 데이터에도 반영하고 마이그레이션

### 승인/결재선 시스템 주의사항 (Polymorphic 공통 모델)

**⚠️ 매우 중요 - 반드시 숙지하세요**

#### 승인/결재선 모델은 공통 시스템입니다
- ApprovalLine, ApprovalRequest, ApprovalHistory 등은 **여러 도메인에서 공통으로 사용하는 Polymorphic 모델**입니다
- 경비(ExpenseItem), 신청서(RequestForm) 등 다양한 모델이 이 시스템을 공유합니다
- **절대 특정 도메인 전용 승인 모델을 별도로 만들지 마세요** (예: ExpenseApproval ❌)

#### 수정 시 주의사항
1. **영향도 분석 필수**: 한 모듈에서 일방적으로 수정하면 다른 모든 모듈에 영향을 미칩니다
2. **테스트 범위**: 승인 관련 수정 시 경비와 신청서 모두 테스트해야 합니다
3. **스키마 변경 금지**: 특정 도메인을 위한 필드 추가는 매우 신중하게 결정하세요
4. **확장 방법**: 새로운 승인 대상 추가는 Polymorphic association으로 처리하세요

#### 올바른 확장 예시
```ruby
# ✅ 올바른 방법 - Polymorphic 사용
class NewFeature < ApplicationRecord
  has_many :approval_requests, as: :approvable
end

# ❌ 잘못된 방법 - 별도 승인 모델 생성
class NewFeatureApproval < ApplicationRecord  # 절대 금지!
end
```

## 로컬 서버 재시작 스크립트

### 사용법
```bash
# 일반 모드 (대화형 - 모든 옵션 선택 가능)
./local.sh

# 빠른 모드 (시드 없음, bin/dev 자동 실행)
./local.sh --quick
./local.sh -q

# 시드만 실행 후 자동 시작 (기존 데이터 유지)
./local.sh --seed
./local.sh -s

# DB 완전 리셋 후 시드 실행, 자동 시작
./local.sh --reset
./local.sh -r

# 조합 사용 가능
./local.sh -q -s  # 빠른 모드 + 시드만 실행
```

### 각 모드 설명
- **일반 모드**: 시드 실행 여부와 서버 시작 방법을 대화형으로 선택
- **빠른 모드 (-q, --quick)**: 시드 없이 bin/dev로 자동 실행 (개발 중 빠른 재시작용)
- **시드 모드 (-s, --seed)**: 기존 데이터를 유지하고 시드만 실행 후 bin/dev로 자동 실행
- **리셋 모드 (-r, --reset)**: DB를 완전히 drop/create 후 시드 실행, bin/dev로 자동 실행 (초기화가 필요할 때)

## Task Master AI 지침

### 필수 명령어

#### 핵심 워크플로우 명령어

```bash
# 프로젝트 설정
task-master init                                    # 현재 프로젝트에서 Task Master 초기화
task-master parse-prd .taskmaster/docs/prd.txt      # PRD 문서에서 작업 생성
task-master models --setup                        # AI 모델 대화형 설정

# 일일 개발 워크플로우
task-master list                                   # 모든 작업을 상태와 함께 표시
task-master next                                   # 다음 작업할 수 있는 작업 가져오기
task-master show <id>                             # 상세 작업 정보 보기 (예: task-master show 1.2)
task-master set-status --id=<id> --status=done    # 작업 완료 표시

# 작업 관리
task-master add-task --prompt="설명" --research        # AI 지원으로 새 작업 추가
task-master expand --id=<id> --research --force              # 작업을 하위 작업으로 분할
task-master update-task --id=<id> --prompt="변경사항"         # 특정 작업 업데이트
task-master update --from=<id> --prompt="변경사항"            # ID부터 여러 작업 업데이트
task-master update-subtask --id=<id> --prompt="노트"        # 하위 작업에 구현 노트 추가

# 분석 및 계획
task-master analyze-complexity --research          # 작업 복잡도 분석
task-master complexity-report                      # 복잡도 분석 보기
task-master expand --all --research               # 모든 적격 작업 확장

# 종속성 및 구성
task-master add-dependency --id=<id> --depends-on=<id>       # 작업 종속성 추가
task-master move --from=<id> --to=<id>                       # 작업 계층 재구성
task-master validate-dependencies                            # 종속성 문제 확인
task-master generate                                         # 작업 마크다운 파일 업데이트 (보통 자동 호출)
```

## 프로젝트 특정 규칙

### 작업 디렉토리 규칙
- **Rails 프로젝트 폴더**: `/Users/kangjinsoo/Desktop/talenx/expense_system-main/` (메인 작업 폴더)
- 모든 Rails 관련 작업과 Task Master 작업은 `expense_system-main/` 폴더 내에서 수행
- **중요**: 모든 tm 작업은 Rails 프로젝트 폴더(`expense_system-main`)에서 진행

### 진행 상황 문서 관리
- **중요**: 모든 작업 진행 상황은 `DAILY_PROGRESS.md` 파일에만 기록
- 별도의 진행 상황 파일 생성 금지 (예: docs/2025-XX-XX-진행상황.md)
- 날짜별로 구분하여 작성, 최신 날짜가 위에 오도록 정렬
- **서브태스크 완료 시 반드시 DAILY_PROGRESS.md 업데이트**
  - 이전 내용을 절대 지우지 않고 상단에 최신 작업 추가
  - 형식: `## YYYY-MM-DD` 헤더 아래에 작업 내용 기록

### Git 커밋 & 푸시 규칙
- **⚠️ 절대 규칙: Tidewave 테스트 없이 커밋 금지**
- **중요**: 모든 코드 변경사항은 커밋 전 반드시 Tidewave 테스트를 통과해야 함
- **Task Master 태스크 작업 시**: 각 하위 작업(n.n 레벨) 완료 후 테스트→커밋→푸시
- **이슈 수정/디버깅 작업 시**: 테스트 후 사용자가 명시적으로 요청할 때만 커밋/푸시

#### 커밋 전 필수 체크리스트
**⚠️ 경고: 아래 항목을 수행하지 않고 커밋하면 안 됩니다**
1. ✅ **Tidewave 테스트 실행 및 통과 확인** (mcp__tidewave__project_eval 사용)
2. ✅ 테스트 결과를 사용자에게 보고
3. ✅ 모든 변경사항이 의도한 대로 작동하는지 확인
4. ✅ 테스트 통과 후에만 커밋 진행

#### 서브태스크 완료 후 필수 작업 순서
  1. **🔴 Tidewave로 기능 테스트 수행** (mcp__tidewave__project_eval 사용) - **필수**
  2. 테스트 통과 확인 (실패 시 수정 후 재테스트)
  3. DAILY_PROGRESS.md 파일 업데이트 (상단에 최신 내용 추가)
  4. 주요 구조가 바뀐 경우 PROJECT_STRUCTURE.md 업데이트
  5. 변경사항 커밋 및 푸시
  6. Task Master 상태 업데이트 (`task-master set-status --id=n.n --status=done`)
  7. 다음 서브태스크로 즉시 진행 (사용자 승인 없이 계속)
- 커밋 메시지 형식: 
  ```
  feat: [Task n.n] <한국어 제목>  # Task 작업 시
  fix: <수정 내용>                # 이슈 수정 시
  
  - 구현한 주요 기능 1
  - 구현한 주요 기능 2
  - 수정사항 또는 개선사항
  ```
- 예시:
  ```
  feat: [Task 5.5] 승인/반려 UI 및 코멘트 기능 구현
  
  - ApprovalsController로 승인자 대시보드 구현
  - 승인 진행 상황 타임라인 UI 추가
  - Turbo Frames를 활용한 실시간 승인/반려 처리
  - 승인/반려 시 코멘트 입력 기능
  - 승인 통계 표시 및 자동 업데이트
  ```
- 커밋 전 항상 테스트 실행 (가능한 경우)
- **중요**: 커밋 메시지에 Claude 관련 내용(:robot_face: 이모지, Claude Code 링크, Co-Authored-By 등) 포함하지 않기

### Task Master 업데이트 규칙
- **중요**: 각 서브태스크 완료 후 반드시 Task Master 상태 업데이트
- 서브태스크 완료 시: `task-master set-status --id=n.n --status=done`
- 새 작업 시작 전: `task-master list`로 현재 상태 확인
- 다음 작업 확인: `task-master next`
- 모든 서브태스크 완료 후 상위 태스크도 완료 처리
- **서브태스크 진행 규칙**:
  - 하나의 서브태스크가 완료되면 바로 다음 서브태스크 진행
  - 사용자 승인을 기다리지 않고 연속적으로 작업
  - 모든 서브태스크 완료 시까지 계속 진행

### 우선순위 가이드라인
- 외부 API 통합보다 핵심 기능에 먼저 집중
- talenx API 통합은 기본 기능이 작동한 후에 수행
- 우선순위: 핵심 모델 → 기본 CRUD → 비즈니스 로직 → 외부 통합

## 프로젝트 구조 문서
- **중요**: 프로젝트 구조와 아키텍처는 `PROJECT_STRUCTURE.md` 파일 참조
- **업데이트 규칙**:
  - 새로운 모델/컨트롤러/서비스 추가 시 즉시 문서 업데이트
  - Task Master 작업 완료 시 관련 섹션 업데이트
  - 주요 리팩토링 후 구조 변경사항 반영
  - 새로운 Stimulus 컨트롤러나 Turbo 패턴 추가 시 프론트엔드 섹션 업데이트
  - 데이터베이스 마이그레이션 후 스키마 섹션 업데이트
  - 경비 항목 정렬 기능 같은 주요 기능 추가 시 관련 섹션 업데이트

## Task Master AI Instructions
**Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**
@./.taskmaster/CLAUDE.md

## Tidewave MCP 테스트 규칙 (최우선 규칙)
**🔴 절대 규칙**: 코드를 변경했으면 무조건 Tidewave 테스트를 실행해야 합니다. 테스트 없이 커밋하는 것은 금지됩니다.
**⚠️ 중요**: 모든 기능 개발, 버그 수정, 리팩토링 완료 후 커밋하기 전에 반드시 Tidewave로 테스트 수행

### 필수 테스트 시점
1. **🔴 커밋하기 전** - 모든 변경사항은 커밋 전 테스트 필수
2. **기능 개발 완료 후** - 신규 기능이 정상 작동하는지 검증
3. **버그/이슈 수정 완료 후** - 수정사항이 문제를 해결했는지 확인
4. **리팩토링 완료 후** - 기존 기능이 여전히 정상 작동하는지 확인
5. **사용자에게 결과 보고 전** - 최종 검증

**⚠️ 테스트를 건너뛰는 경우**:
- 문서 파일(*.md)만 수정한 경우
- 주석만 수정한 경우
- 코드 포맷팅만 변경한 경우

**🔴 테스트가 필수인 경우**:
- 모든 Ruby 코드 변경
- 모든 JavaScript/Stimulus 코드 변경
- 모든 HTML/ERB 템플릿 변경
- 모든 데이터베이스 마이그레이션
- 모든 설정 파일 변경

### 테스트 수행 방법
```ruby
# Tidewave MCP 도구 사용
mcp__tidewave__project_eval

# 테스트 코드 구조
puts "=" * 60
puts "기능명 테스트 - Tidewave MCP"
puts "=" * 60

# 1. 데이터 준비
# 2. 기능 실행
# 3. 결과 검증
# 4. 성공/실패 보고
```

### 테스트 항목별 예시

#### 1. 모델 테스트
```ruby
# 모델 생성 및 검증
model = ModelName.new(attributes)
puts "유효성: #{model.valid? ? '✅' : '❌'}"
puts "에러: #{model.errors.full_messages.join(', ')}" if model.errors.any?
```

#### 2. 컨트롤러/API 테스트
```ruby
# API 엔드포인트 테스트
response = ApiController.new.action_name(params)
puts "상태: #{response[:status]}"
puts "결과: #{response[:data]}"
```

#### 3. 서비스 객체 테스트
```ruby
# 서비스 로직 테스트
service = ServiceClass.new(params)
result = service.call
puts "성공: #{result[:success] ? '✅' : '❌'}"
puts "메시지: #{result[:message]}"
```

#### 4. 통합 테스트
```ruby
# 전체 플로우 테스트
user = User.find_or_create_by(email: 'test@example.com')
sheet = ExpenseSheet.create(user: user, ...)
validator = ExpenseSheetApprovalValidator.new
result = validator.validate(sheet, approval_line)
puts "검증 결과: #{result[:valid] ? '✅ 통과' : '❌ 실패'}"
```

### 테스트 보고 형식
1. **테스트 제목** - 무엇을 테스트하는지 명시
2. **테스트 시나리오** - 어떤 상황을 테스트하는지 설명
3. **예상 결과** - 기대하는 동작
4. **실제 결과** - 실제로 발생한 동작
5. **판정** - ✅ 성공 / ❌ 실패 / ⚠️ 부분 성공

### 테스트 실패 시 조치
1. 에러 메시지 분석
2. 코드 수정
3. 재테스트 수행
4. 성공할 때까지 반복
5. **🔴 테스트 통과 전까지 절대 커밋 금지**

### 커밋 시도 시 자동 확인 사항
- "Tidewave 테스트를 실행했습니까?" → NO면 테스트 먼저 실행
- "모든 테스트가 통과했습니까?" → NO면 수정 후 재테스트
- "테스트 결과를 DAILY_PROGRESS.md에 기록했습니까?" → NO면 기록 후 진행

## 진행 상황 문서 업데이트 규칙
- **중요**: 기능 개발/버그 수정 완료 후 Tidewave 테스트를 통과한 경우에만 완료로 기록
- 사용자에게 테스트 결과 요약 제공 (어느 페이지에서 어떤 프로세스로 확인 가능한지 안내)