*최종 업데이트: 2025-09-10 14:20:00 KST*

## 2025-09-10 (경비 마감 대시보드 일괄 마감 버그 수정)

### 일괄 마감 처리 시 대시보드 숫자 업데이트 안 되는 문제 해결
- **문제점**: 일괄 마감 처리 후 "마감완료" 숫자가 페이지 새로고침 없이는 업데이트되지 않음
- **원인 분석**:
  1. JavaScript에서 batch_close 요청 시 year/month 파라미터를 전송하지 않음
  2. 서버가 현재 날짜(9월)를 사용하여 잘못된 데이터 조회
  3. URL은 `month=6`인데 서버는 `month=9` 데이터를 처리
- **해결**:
  - `closing_dashboard_controller.js`의 `performBatchClose` 메서드 수정
  - year, month, include_descendants 파라미터 추가
  - 불필요한 JavaScript 디버깅 코드 제거 (Turbo는 동적 script 태그 실행 안 함)
- **결과**: 일괄 마감 처리 시 올바른 월의 데이터가 업데이트되고 대시보드 숫자가 즉시 반영됨

### 경비 마감 대시보드 성능 최적화
- **문제점**: 240명 기준 2초 이상 소요 (N+1 쿼리 문제)
- **원인**: 각 사용자마다 ExpenseSheet와 ExpenseItem을 개별 조회 (480+ 쿼리)
- **해결**:
  - `ExpenseClosingStatus.bulk_sync_with_expense_sheets` 메서드 구현
  - 벌크 처리로 모든 데이터를 3-4개 쿼리로 처리
  - includes를 활용한 Eager Loading
- **결과**: 93.2% 성능 개선 (2초 → 136ms)

### ExpenseSheet 상태 동기화 문제 수정
- **문제점**: ApprovalRequest는 'approved'인데 ExpenseSheet는 'submitted' 상태 유지
- **원인**: ApprovalRequest 승인 시 ExpenseSheet 상태 업데이트 누락
- **해결**: `ApprovalRequest#process_approval` 메서드에 ExpenseSheet 처리 추가
- **주의사항**: ApprovalRequest는 Polymorphic 공통 모델이므로 다른 모듈 영향 최소화

### 일괄 마감용 체크박스 구현
- **문제점**: 자동 마감 로직이 수동 마감을 방해
- **해결**: `bulk_sync_with_expense_sheets`에서 자동 마감 로직 제거
- **결과**: 승인 완료된 항목에 체크박스가 표시되고 선택적 일괄 마감 가능

## 2025-09-08 (경비 마감 대시보드 조직 선택 개선)

### 조직 브라우저 UI 개선
- **"하위 조직 포함" 체크박스 기본값 변경**
  - 기존: 체크 해제 상태가 기본
  - 변경: 체크된 상태가 기본 (사용자 편의성 개선)
  - `_organization_browser.html.erb`에서 `params[:include_descendants] != 'false'` 조건으로 변경

- **조직 트리 인원 수 표시 제거**
  - 경비 통계 트리와 동일한 UI로 통일
  - `_organization_tree_node.html.erb`에서 멤버 수 표시 섹션 제거
  - 더 깔끔한 트리 구조 제공

### 조직 선택 버그 수정
- **문제점**: 하위 조직 선택 시 루트 조직(휴먼컨설팅그룹)으로 자동 리셋되는 현상
- **원인**: 컨트롤러에서 `@managed_organizations`에서만 조직을 찾아서 발생
- **해결**:
  - `Admin::Closing::DashboardController`에서 전체 조직에서 검색하도록 수정
  - `Organization.find_by(id: params[:organization_id])`로 변경
  - 권한 체크는 별도로 수행 (`can_manage_organization_expense?`)
- **결과**: 모든 하위 조직 선택이 정상적으로 유지됨

## 2025-09-07 (AI 요약 표시 일관성 개선)

### AI 요약 표시 통일
- **문제점**
  - 제출 페이지: JavaScript(attachment_uploader_controller.js)에서 HTML 직접 생성
  - 승인 페이지: 서버 partial(expense_attachments/_summary.html.erb) 사용
  - 두 페이지에서 레이아웃과 스타일이 달라 일관성 부족

- **해결 방법**
  - ExpenseAttachmentsController에 summary_html 액션 추가
  - JavaScript에서 서버 렌더링 HTML을 가져와 사용하도록 수정
  - Fallback 메서드 추가로 서버 요청 실패 시에도 동일한 스타일 유지

- **구현 내용**
  1. 서버 엔드포인트 추가 (/expense_attachments/:id/summary_html)
  2. JavaScript showTextModal 메서드를 async로 변경
  3. 서버 partial과 동일한 레이아웃의 fallback 메서드 구현
  4. View에 필요한 data 속성 추가 (expense_sheet_id, expense_item_id)

- **결과**
  - 제출 페이지와 승인 페이지에서 AI 요약이 완전히 동일하게 표시
  - 통신비 영수증의 부가 서비스, 기타 요금, 할인 금액 필드도 정상 표시
  - 서버 중심 렌더링으로 유지보수성 향상

## 2025-09-04 (승인 페이지 표시 개선)

### 승인 목록 날짜 및 내용 표시 개선
- **신청일시 표시 형식 변경**
  - 기존: YYYY-MM-DD 형식
  - 변경: YYYY-MM-DD HH:MM 형식 (예: 2024-09-09 13:51)
  - 테이블 뷰와 카드 뷰 모두 적용

- **경비 항목 제목 표시 개선**
  - 기존: "경비코드명 - 금액"
  - 변경: "MM/DD - 경비코드명 - 금액" 
  - 예: "06/10 - 초과근무 식대 - ₩14,800"
  - 경비 사용 날짜를 제목에 포함하여 직관적으로 확인 가능

- **경비 항목 설명 표시 개선**
  - 기존: 설명 텍스트만 표시
  - 변경: "설명 (사용자명)" 형식
  - 예: "야근식대 (김민영)_프로덕션테스트"
  - 경비 사용자를 명확히 표시

- **규칙 유형 표시 텍스트 간소화**
  - 총금액 조건 → 총금액
  - 항목수 조건 → 항목수  
  - 제출자 기반 → 제출자
  - 경비 코드 포함 → 코드포함
  - 사용자 정의 → 기타

## 2025-09-04 (경비 시트 승인 규칙 시드 데이터 재설계)

### 승인 규칙 시드 데이터 전면 재구성
- **요구사항에 맞춘 새로운 규칙 구조**
  1. 기본 규칙 (총금액 >= 0): 보직자, 조직리더 승인 필요
  2. 제출자가 보직자: 조직리더, 조직총괄 승인 필요
  3. 제출자가 조직리더: 조직총괄, CEO 승인 필요
  4. 제출자가 조직총괄: CEO 승인 필요
  5. ENTN(접대비) 또는 EQUM(기기/비품비) 포함: 조직총괄, CEO 승인 필요

- **복수 승인자 그룹 지원 방식**
  - 동일 조건에 대해 여러 개의 규칙 생성
  - 예: 기본 조건에 보직자 규칙과 조직리더 규칙 각각 생성
  - 현재 모델 구조 유지하면서 요구사항 충족

- **경비 코드 수정**
  - EQUN → EQUM(기기/비품비)로 수정
  - 실제 데이터베이스의 경비 코드와 일치시킴

- **테스트 결과**
  - 일반 사용자: 보직자, 조직리더 승인 필요
  - 접대비(ENTN) 포함 시: 추가로 조직총괄, CEO 승인 필요
  - 기기/비품비(EQUM) 포함 시: 추가로 조직총괄, CEO 승인 필요
  - 모든 케이스에서 정상 작동 확인

## 2025-09-04 (경비 코드 기반 승인 규칙 추가)

### 경비 코드 기반 승인 조건 구현
- **모델 업데이트 (ExpenseSheetApprovalRule)**
  - `expense_code_based` 규칙 유형 추가
  - `#경비코드:CODE1,CODE2` 형식의 조건 평가 로직 구현
  - 숫자를 포함한 경비 코드 (예: TRAVEL001) 지원을 위해 정규식 개선
  - OR 조건으로 여러 경비 코드 중 하나라도 포함되면 규칙 적용

- **검증 서비스 개선 (ExpenseSheetApprovalValidator)**
  - 경비 시트의 경비 코드 목록을 context에 추가
  - 경비 항목들의 고유 경비 코드를 수집하여 규칙 평가에 활용

- **관리자 UI 개선**
  - 규칙 유형에 "경비 코드 포함" 옵션 추가
  - 경비 코드 선택을 위한 체크박스 리스트 UI 구현
  - 스크롤 가능한 경비 코드 목록 (max-h-48 overflow-y-auto)
  - JavaScript condition builder에 expense code 타겟 추가

- **컨트롤러 로직 추가**
  - `build_condition` 메서드에 expense_code_based 처리 로직 추가
  - 선택된 경비 코드들을 `#경비코드:CODE1,CODE2` 형식으로 변환

- **시드 데이터 업데이트**
  - 접대비(ENTN) 포함 시 CEO 승인 필수 규칙 추가
  - 회의비(CONF) 또는 교육비(EDU) 포함 시 경영지원 승인 규칙 추가
  - 총 9개의 다양한 승인 규칙 시드 데이터 구성

- **테스트 결과**
  - 7/8 테스트 성공 (모델 단위 테스트)
  - 단일 및 복수 경비 코드 매칭 정상 작동
  - 복합 조건 (경비 코드 + 금액) 평가 성공
  - 활성/비활성 규칙 필터링 정상 작동

## 2025-09-03 (경비 시트 승인 규칙 시스템 구현)

### 경비 시트 승인 규칙 시스템 구현 완료
- **데이터베이스 구조**
  - `expense_sheet_approval_rules` 테이블 생성
  - 총금액, 항목수, 제출자 기반 조건 지원
  - 우선순위 기반 규칙 평가 시스템

- **모델 구현 (ExpenseSheetApprovalRule)**
  - 다양한 규칙 유형 지원 (total_amount, item_count, submitter_based, custom)
  - 조건식 평가 로직 (`#총금액 > 5000000` 형식)
  - 제출자 그룹 기반 규칙 적용
  - 승인자 그룹과의 연관 관계

- **검증 서비스 (ExpenseSheetApprovalValidator)**
  - 경비 시트 레벨 검증
  - 기존 경비 항목 검증 재사용
  - 통합된 에러/경고 메시지 형식
  - "승인 필요:", "필수 아님:" 형식의 일관된 메시지

- **관리자 UI**
  - `/admin/expense_sheet_approval_rules` 관리 페이지
  - Turbo Frames를 활용한 모달 폼
  - 규칙 유형별 동적 폼 필드 (Stimulus 컨트롤러)
  - 활성/비활성 토글 기능
  - 실시간 규칙 편집 및 삭제

- **API 엔드포인트**
  - `/api/expense_sheets/validate_approval_line` - 실시간 검증
  - 경비 시트 제출 시 자동 검증

- **시드 데이터**
  - 7개의 기본 승인 규칙 생성
  - CEO, 조직총괄, 조직리더 등 계층별 승인 체계
  - 총금액 및 항목수 기반 조건부 규칙

## 2025-09-03 (Turbo 호환성 개선 및 버그 수정)

### 회의실 예약 시스템 버그 수정
- **회의실 예약 삭제 404 에러 수정**
  - `room_calendar_controller.js`의 fetch URL을 절대 경로로 변경
  - `window.location.origin` 사용하여 올바른 경로 구성
  
- **삭제 확인 2번 뜨는 문제 해결**
  - `data-controller="room-calendar"` 중복 선언 제거
  - tbody에서 제거하고 최상위 div만 유지
  - calendar.html.erb 및 모든 turbo_stream.erb 파일 수정
  
- **필터링 후 수정/삭제 버튼 작동 안 하는 문제 해결**  
  - 이벤트 리스너를 최상위 container에 등록
  - tbody 교체 후에도 이벤트 유지되도록 개선
  - 캘린더 그리드 내부 이벤트만 처리하도록 필터링

### 어드민 경비 시트 관리 UI 개선
- **연도-월 선택 컴포넌트 통합**
  - 별도의 연도/월 드롭다운을 HTML5 month_field로 통합
  - `app/views/admin/expense_sheets/index.html.erb` 수정
  - `Admin::ExpenseSheetsController`에 year_month 파라미터 처리 추가
  - 한 번의 클릭으로 연도-월 동시 선택 가능

## 2025-09-03 (Turbo 호환성 개선)

### Task #55: 조직 폼 Turbo 호환성 개선 ✅
- `app/views/organizations/_form.html.erb`에서 `local: true` 제거
- `OrganizationsController`의 나머지 리다이렉트에 `status: :see_other` 추가
  - destroy, assign_manager, remove_manager, add_user, remove_user 액션 수정
- 조직 생성/수정 및 관리 작업 시 페이지 새로고침 없이 처리 개선
- 테스트: http://localhost:3000/organizations/new 에서 조직 생성 시 페이지 새로고침 없이 처리됨

### Task #54: 사용자 폼 Turbo 호환성 개선 ✅
- `app/views/users/_form.html.erb`에서 `local: true` 제거
- `UsersController`의 create/update 액션에 `status: :see_other` 추가
- 사용자 생성/수정 후 상세 페이지로 리다이렉션 개선
- 테스트: http://localhost:3000/users/new 에서 사용자 생성 시 페이지 새로고침 없이 처리됨

### Task #53: 어드민 신청서 카테고리 폼 Turbo 호환성 개선 ✅
- `app/views/admin/request_categories/_form.html.erb`에서 `local: true` 제거
- `Admin::RequestCategoriesController`의 모든 리다이렉트에 `status: :see_other` 추가
  - create, update, destroy, toggle_active 액션 수정
- 카테고리 생성/수정 후 목록 페이지로 리다이렉션 개선
- 테스트: http://localhost:3000/admin/request_categories/new 에서 카테고리 생성 시 페이지 새로고침 없이 처리됨

### Task #52: 어드민 신청서 템플릿 폼 Turbo 호환성 개선 ✅
- `app/views/admin/request_templates/_form.html.erb`에서 `local: true` 제거
- `Admin::RequestTemplatesController`의 모든 리다이렉트에 `status: :see_other` 추가
  - create, update, destroy, toggle_active, duplicate 액션 수정
- 템플릿 생성/수정 후 상세 페이지로 리다이렉션됨
- 테스트: http://localhost:3000/admin/request_templates/new 에서 템플릿 생성 시 페이지 새로고침 없이 처리됨

### Task #51: 어드민 경비 시트 목록 검색 폼 Turbo 호환성 개선 ✅
- `app/views/admin/expense_sheets/index.html.erb`에서 `local: true` 제거
- 검색 결과를 `turbo_frame_tag "expense_sheets_list"`로 감싸서 부분 업데이트 구현
- 폼 제출 시 `data: { turbo_frame: "expense_sheets_list" }` 타겟 지정
- 페이지네이션 링크에도 Turbo Frame 타겟 추가
- `Admin::ExpenseSheetsController`에 Turbo Frame 요청 처리 추가
- 테스트: http://localhost:3000/admin/expense_sheets 에서 필터 적용 시 목록만 업데이트됨

### Task #50: 로그인 폼 Turbo 호환성 개선 ✅
- `app/views/sessions/new.html.erb`에서 `local: true` 제거
- `SessionsController`의 create/destroy 액션에 `status: :see_other` 추가
- 로그인 성공/실패 시 Turbo를 통한 처리로 전체 페이지 새로고침 제거
- 테스트: http://localhost:3000/login 에서 로그인 시 페이지 새로고침 없이 처리됨

### Turbo 호환성 개선 작업 시작
- Task Master에 Turbo 호환성 개선 작업 6개 추가 (Task #50-55)
- 우선순위: 로그인 → 어드민 경비 시트 → 신청서 템플릿/카테고리 → 사용자/조직 관리

### 신청서 및 결재선 시드 데이터 추가
- 신청서 카테고리: 정보보안
- 신청서 템플릿: 12개 (사용자 계정 신청서, VPN 계정 신청서 등)
- 샘플 신청서: 10개
- 모든 사용자에게 기본 결재선 생성 (조직 계층 기반)

## 2025-08-31 (회의실 카테고리 관리 시스템 구현)

### 회의실 카테고리 관리 기능 추가
- **요구사항**: 회의실의 "지점"을 "카테고리"로 변경하고 동적 관리 가능하도록 개선
- **구현 방식**: RequestCategory와 동일한 패턴으로 RoomCategory 모델 및 관리 기능 구현

#### 주요 구현 내용
1. **데이터베이스 구조**:
   - `room_categories` 테이블 생성 (name, description, display_order, is_active)
   - `rooms` 테이블에 `room_category_id` 외래키 추가
   - 기존 하드코딩된 카테고리('강남', '판교', '서초')를 DB로 마이그레이션

2. **모델 구현**:
   - `RoomCategory` 모델: 카테고리 관리 (RequestCategory와 동일 구조)
   - `Room` 모델 업데이트: belongs_to :room_category 관계 추가
   - 검증 규칙 및 스코프 구현

3. **컨트롤러 구현**:
   - `Admin::RoomCategoriesController`: CRUD 및 활성화 토글 기능
   - `Admin::RoomsController` 수정: room_category 지원

4. **뷰 구현**:
   - 카테고리 관리 페이지 (목록, 생성, 수정)
   - Room 관련 뷰에서 "지점" → "카테고리" 레이블 변경
   - 드롭다운을 동적 카테고리 선택으로 변경

5. **관리자 메뉴 개선**:
   - 회의실 메뉴를 2단 드롭다운 구조로 변경 (신청서와 동일)
   - 회의실 > 카테고리, 회의실 > 회의실
   - admin 레이아웃에 Tailwind CSS 추가 (CSS 적용 문제 해결)

#### 데이터 마이그레이션
- `rake room_categories:migrate` 태스크로 기존 데이터 이전
- 강남/판교/서초 카테고리 자동 생성 및 회의실 연결

## 2025-08-31 (추가 개선)

### 조직별 경비 통계 연도별 브라우징 기능 추가

#### 구현 내용
- **요구사항**: 기존 월별 브라우징만 가능했던 조직별 경비 통계를 연도별로도 볼 수 있도록 개선
- **구현 방식**: 최소한의 인터페이스 변경으로 월별/연도별 토글 기능 추가

#### 주요 변경사항
1. **컨트롤러 수정** (`organization_expenses_controller.rb`):
   - `set_date_params` 메서드에 `view_mode` 파라미터 처리 추가
   - 연도별 모드에서는 month 조건 없이 전체 연도 데이터 조회
   - `@prev_year`, `@next_year` 변수 추가로 연도 네비게이션 지원

2. **뷰 업데이트** (`index.html.erb`):
   - 월별/연도별 토글 버튼 추가 (우상단)
   - 네비게이션 버튼이 view_mode에 따라 동적으로 작동
   - 기간 표시 텍스트가 모드에 따라 변경

3. **JavaScript 수정** (`organization_chart_controller.js`):
   - `loadOrganizationDetails`: AJAX 호출 시 view_mode 파라미터 전달
   - `updatePageTitle`: 연도별 모드에서는 월 없이 표시

#### 기능 특징
- URL 파라미터로 상태 관리: `?view_mode=yearly&year=2024`
- 기본값은 월별 모드 유지 (기존 동작과 호환)
- Turbo Frames를 활용한 부드러운 전환
- 모든 차트와 통계가 선택된 모드에 맞게 자동 조정

## 2025-08-31 (추가 수정 2)

### 경비 항목 페이지 이탈 경고 개선

#### Turbo 네비게이션 시 경고 표시
- **문제**: 경비 항목 폼에서 변경사항이 있을 때 Turbo 링크 클릭 시 경고 없이 이동
- **원인**: Turbo는 `beforeunload` 이벤트를 트리거하지 않음
- **해결**:
  - `autosave_controller.js`에 `turbo:before-visit` 이벤트 처리 추가
  - 바인딩된 함수 참조 저장으로 이벤트 리스너 정확히 제거
  - TO-DO 주석 추가: 향후 경비 항목 폼을 Turbo로 전환 필요

#### 결재선 소프트 삭제 구현
- **문제**: 외래 키 제약으로 인한 삭제 문제
- **해결**: 
  - `deleted_at` 컬럼 추가로 소프트 삭제 구현
  - 삭제된 결재선은 목록에서 제외 (active 스코프)
  - 데이터 무결성 유지하면서 안전한 삭제

## 2025-08-31 (추가 수정)

### 결재선 관리 시스템 버그 수정

#### 결재선 이름 트림 처리
- **문제**: "기본"과 " 기본" (공백 포함)을 다른 이름으로 인식
- **해결**:
  - ApprovalLine 모델: `before_validation :strip_name` 콜백 추가
  - ApprovalLinesController: `approval_line_params`에서 name 트림 처리
  - 대소문자 구분 없는 유니크 검증: `case_sensitive: false` 옵션 추가

## 2025-08-31

### 경비 항목 검증 시스템 개선

#### unified-validation-controller 제거 및 client-validation 통합
- **문제점**: 
  - unified-validation-controller가 실제로 사용되지 않음 (이벤트 연결 없음)
  - client-validation-controller와 중복된 코드 존재
  - 불필요한 복잡도 증가
- **해결책**:
  - unified-validation-controller.js 완전 제거
  - 모든 검증 로직을 client-validation-controller로 통합
  - 날짜 검증 기능 client-validation에 복원

#### 제출된 시트 날짜 검증 기능 강화
- **날짜 선택 시 실시간 검증**:
  - 제출된 시트의 날짜 선택 시 즉시 에러 표시
  - 저장 버튼 비활성화 및 오류 개수 표시
- **기본값 날짜 검증 추가**:
  - 폼 로드 시 기본 날짜값(마지막 입력 날짜)에 대한 자동 검증
  - data-needs-validation 속성으로 초기 검증 필요 여부 표시

#### 버튼 텍스트 오류 표시 개선
- **INPUT 태그 지원**: form.submit이 생성하는 input[type="submit"] 요소 처리
- **오류 개수 표시**: "저장 (오류 N개)" 형식으로 명확한 피드백 제공

## 2025-08-30

### 회의실 예약 시스템 성능 최적화 및 안정성 개선

#### Bullet gem 경고 해결 (N+1 쿼리 제거)
- **문제점**: Room과 room_reservations 간 불필요한 eager loading 
- **해결책**: 
  - `Room.includes(:room_reservations)` 제거 (실제 사용 안 함)
  - `RoomReservation.includes(:room)` → `.includes(:user)`로 변경

#### 드래그앤드롭/리사이징 UX 개선
- **Optimistic UI 패턴 적용**
  - 드롭 후 미리보기를 유지하여 서버 응답 대기 중 깜빡임 제거
  - 원본 예약은 숨기고 미리보기만 표시
- **리사이징 기능 추가**
  - 예약 카드 상단/하단 핸들로 시간 조정 가능
  - 실시간 미리보기 제공

#### 에러 처리 강화
- **시간 중복 에러 발생 시**:
  1. 미리보기 즉시 제거
  2. 원본 예약 다시 표시
  3. 에러 메시지 출력
  4. Turbo.visit으로 페이지 새로고침하여 완전 복원
- **Turbo 규칙 준수**: DOM 직접 조작 최소화

#### 세션 기반 필터 유지
- 지점 필터 선택 상태를 세션에 저장
- 예약 생성/수정 후에도 필터 상태 유지

## 2025-08-29

### 회의실 예약 시스템 전면 개선

#### 캘린더 렌더링 방식 전환 (rowspan → 오버레이)
- **문제점**: rowspan 기반 테이블 렌더링 시 드래그 앤 드롭 미리보기가 예약된 셀에서 표시되지 않음
- **해결책**: 오버레이 기반 렌더링으로 전환
  - `room_calendar_controller.js` 완전 재작성
  - 새로운 `_calendar_grid.html.erb` 부분 뷰 생성
  - CSS absolute positioning을 활용한 예약 오버레이 렌더링

#### 드래그 앤 드롭 기능 개선
- **모든 셀에서 드래그 미리보기 가능**
  - pointer-events 관리로 드래그 중 오버레이 투과 처리
  - 드래그 중인 예약만 opacity 감소, 다른 예약은 정상 표시
- **시간 계산 버그 수정**
  - 문제: 드래그 종료 시점의 마우스 위치로 계산하여 부정확
  - 해결: 마지막 유효 셀 위치 저장 방식으로 변경
- **드래그 미리보기 텍스트 개선**
  - 형식: "[카테고리] 회의실명 HH:MM~HH:MM"
  - 예: "판교 대회의실 09:00~10:00"

#### 빈 셀 드래그로 예약 생성 기능
- **빈 셀에서 드래그하여 시간 범위 선택**
  - 드래그 시작점과 끝점으로 시간 자동 계산
  - 선택된 회의실과 시간이 자동으로 폼에 입력
- **모달 포커스 차별화**
  - "+" 버튼으로 열기: 회의실 선택 드롭다운에 포커스
  - 드래그로 생성: 사용 목적 입력란에 포커스 및 텍스트 선택
  - from_drag 파라미터로 구분 처리

#### UI/UX 개선사항
- **카테고리 칩 정렬**
  - DB 생성 순서대로 표시 (강남 → 판교 → 서초)
  - `.order(:id).pluck(:category)` 사용
- **시간 선택 제한**
  - 시작 시간: 09:00~17:45
  - 종료 시간: 09:15~18:00
  - 15분 단위로 선택 가능
- **사용 목적 필드 개선**
  - text_area에서 text_field로 변경
  - data-purpose-input 속성 추가로 포커스 타겟팅
- **오류 메시지 상세화**
  - JSON 응답에 errors 배열과 error 문자열 모두 포함
  - 유효성 검사 실패 시 구체적인 오류 내용 표시

#### 데이터베이스 및 시드 정리
- **회의실 시드 순서 조정**
  - 강남 → 판교 → 서초 순으로 재정렬
- **중복 시드 파일 제거**
  - `db/seeds/25_request_categories.rb` 삭제
  - `db/seeds/25_request_templates_with_fields.rb` 삭제
  - `010_request_categories_and_templates.rb`로 통합
- **성능 테스트용 시드 추가**
  - `020_performance_test_expense_data.rb` 생성
  - 대량 데이터 생성 로직 포함

## 2025-08-28

### Task 45 완료: 승인 시스템 통합 (경비/신청서 Polymorphic 변환)

#### Task 45.6-45.8 완료: 컨트롤러 및 UI 통합
- **ApprovalsController 수정**
  - index 액션에서 ExpenseItem과 RequestForm 모두 처리
  - SQL 조인을 사용한 polymorphic 쿼리 구현
  - show 액션에서 approvable 타입별 데이터 로드
  - 권한 확인 로직을 polymorphic에 맞게 수정

- **승인 대시보드 UI 개선**
  - 테이블에 "유형" 컬럼 추가하여 경비/신청서 구분
  - 경비: 파란색 배지 (bg-blue-100)
  - 신청서: 보라색 배지 (bg-purple-100)
  - 각 타입별로 적절한 정보 표시 (경비코드 vs 템플릿명)
  - 신청서의 경우 금액 대신 "-" 표시
  - 모바일 뷰에서도 타입 배지 표시

- **통합 테스트 및 검증**
  - test_approval_integration.rb 스크립트 작성
  - 경비 항목과 신청서 모두 승인 요청 생성 테스트
  - polymorphic 관계 정상 작동 확인
  - 승인자 관점에서의 목록 조회 테스트
  - 승인 처리 프로세스 검증

#### Task 45.1-45.5 완료: Polymorphic 기반 구조 구축 및 모델 관계 설정
- **ApprovalRequest 테이블 Polymorphic 변환**
  - approvable_type, approvable_id 컬럼 추가
  - 기존 expense_item_id 데이터를 polymorphic으로 자동 마이그레이션
  - unique 인덱스를 polymorphic 구조로 변경
  
- **ApprovalRequest 모델 수정**
  - belongs_to :approvable, polymorphic: true 관계 추가
  - 검증 로직을 polymorphic 구조에 맞게 수정
  - create_with_approval_line 메서드를 범용적으로 변경
  - ExpenseItem과 RequestForm 모두 지원하도록 메서드 수정
  - 승인/반려 시 각 모델별 상태 업데이트 로직 추가

- **모든 관련 모델에 Polymorphic 관계 추가**
  - ExpenseItem: has_many :approval_requests, as: :approvable
  - ExpenseSheet: has_many :direct_approval_requests, as: :approvable
  - ExpenseCode: has_many :approval_requests, as: :approvable
  - RequestForm: has_many :approval_requests, as: :approvable 및 콜백 활성화

### 신청서 시스템 버그 수정 및 개선

#### 결재선 검증 로직 수정
- **신청서 폼 결재선 검증 오류 해결**
  - request_form_validation_controller.js: "결재 없음" 선택 시 오류로 인식하도록 수정
  - 결재선이 필요한데 선택하지 않은 경우 validationErrors Map에 추가
  - 결재선 선택 후에도 오류가 유지되던 문제 해결 (return 문 추가)
  - 라디오 버튼 변경 리스너 추가로 실시간 검증

- **사용자 권한 그룹 표시 개선**
  - 여러 권한 그룹을 가진 사용자의 경우 최상위 권한으로 표시
  - max_by(&:priority) 사용하여 CEO > 조직총괄 > 조직리더 > 보직자 순으로 표시
  - 결재선 미리보기 및 승인 진행 상황에서 일관되게 적용

#### 중복 페이지 제거 및 플로우 개선
- **불필요한 결재선 선택 페이지 제거**
  - select_approval_line.html.erb 뷰 파일 삭제
  - RequestFormsController에서 select_approval_line, submit 액션 제거
  - routes.rb에서 관련 라우트 제거
  - 신청서 폼에서 직접 결재선 선택 후 제출하도록 단순화

- **RequestForm 모델 오류 수정**
  - Polymorphic 관계 임시 비활성화 (DB 스키마 미지원)
  - approval_request 관계 주석 처리
  - create_approval_request_if_needed 콜백 비활성화
  - show/index 뷰에서 존재하지 않는 필드(purpose, content, description) 참조 제거

#### 검증 메시지 일관성 개선
- 경비 항목과 동일한 형식으로 메시지 통일
- 권한 그룹 우선순위 정렬 적용
- 정확히 충족 시 메시지 표시 안 함

## 2025-08-27 (저녁 작업)

### Task 44 완료: 사용자 신청서 작성 및 제출 인터페이스 구현

#### RequestFormsController 및 다단계 폼 플로우 구현
- **사용자 신청서 작성 기능 완성**
  - RequestFormsController: 신청서 CRUD 및 제출 플로우 구현
  - 다단계 폼 프로세스: 카테고리 선택 → 템플릿 선택 → 폼 작성 → 결재선 선택 → 제출
  - 임시저장 및 자동저장 기능
  - before_action으로 권한 체크 및 수정 가능 상태 확인

- **동적 필드 렌더링 시스템**
  - 템플릿 기반 동적 폼 생성 (_form.html.erb)
  - 필드 타입별 적절한 입력 컨트롤 렌더링 (text, textarea, select, date, checkbox)
  - 필수 필드 표시 및 클라이언트 사이드 검증
  - form_data JSON 필드에 동적 데이터 저장

- **파일 업로드 기능**
  - Active Storage를 활용한 첨부파일 관리
  - RequestFormAttachment 모델로 파일 메타데이터 추가 저장
  - 다중 파일 업로드 지원
  - 업로드된 파일 목록 표시 및 다운로드 기능

- **결재선 통합**
  - 사용자 결재선 선택 페이지 구현
  - 템플릿 승인 규칙 기반 필수 승인자 표시
  - 제출 시 첫 번째 승인자에게 자동으로 승인 요청 생성
  - 승인 진행 상황 타임라인 UI

- **UI/UX 구현**
  - Breadcrumb 네비게이션으로 단계 표시
  - Stimulus 컨트롤러로 폼 검증 및 알림
  - 카드 형식의 카테고리/템플릿 선택 UI
  - 상태별 색상 코딩 (임시저장, 승인중, 승인완료, 반려)
  - Pagy 페이지네이션 적용

- **네비게이션 메뉴 업데이트**
  - 데스크톱 및 모바일 메뉴에 "신청서" 링크 추가
  - 기존 메뉴 순서: 경비 → 경비통계 → 승인 → 결재선 → **신청서** → 회의실 → 관리자

#### Task Master 진행 상황 업데이트
- Task 44 완료: 신청서 작성 및 제출 기능
- 전체 진행률: 75.00% (48개 작업 중 36개 완료)
- 다음 작업: Task 45 (승인자 대시보드 및 프로세스)

## 2025-08-27 (오후 작업)

### 신청서 템플릿 관리 시스템 완성

#### Task 42 완료: 신청서 카테고리 및 템플릿 관리 기능
- **Admin 네임스페이스 관리 기능 구현**
  - RequestCategoriesController: 카테고리 CRUD 및 순서 변경
  - RequestTemplatesController: 템플릿 CRUD, 필드 관리, 복제 기능
  - Admin::BaseController 상속으로 관리자 권한 체크
  - 관리자 전용 GNB 메뉴 통합 (신청서 > 카테고리, 템플릿)

- **필드 구조 개선**
  - 필수/선택 필드 구분에서 통합 필드 리스트로 변경
  - 각 필드에 is_required 플래그로 필수 여부 관리
  - 마이그레이션: required_fields, optional_fields → fields로 통합
  - 시드 데이터 12개 템플릿 모두 새 구조로 변환

- **승인 규칙 관리 기능 추가**
  - 경비 코드 승인 규칙 파셜 재사용
  - RequestTemplateApprovalRule 모델 및 관계 설정
  - 드래그앤드롭으로 규칙 순서 변경 (approval_rules_dragdrop_controller.js 수정)
  - 조건식 비어있으면 모든 경우 적용 (기본 승인자)
  - 시드 데이터에 기본 승인 규칙 추가 (보직자, 조직리더)

- **UI/UX 개선**
  - 카테고리 아이콘/색상 필드 완전 제거 (DB 컬럼까지 삭제)
  - Bootstrap에서 Tailwind CSS로 전체 UI 통일
  - Sortable.js로 카테고리 및 템플릿 순서 변경
  - 필드 드래그앤드롭으로 순서 변경 가능

- **Task Master 진행 상황**
  - Task 42 완료 (카테고리 및 템플릿 관리)
  - 다음 작업: Task 43 (사용자 신청서 제출 인터페이스)
  - 전체 진행률: 72.92% (48개 작업 중 35개 완료)

## 2025-08-27 (추가 작업)

### 신청서 관리 시스템 구현 시작

#### Task 41 완료: 데이터베이스 모델 및 마이그레이션 생성
- **신청서 관리 시스템 기본 구조 구축**
  - RequestCategory 모델: 신청서 카테고리 관리 (정보보안, 교육, 복리후생 등)
  - RequestTemplate 모델: 신청서 템플릿 정의
  - RequestTemplateField 모델: 동적 필드 정의 (텍스트, 숫자, 날짜, 선택박스 등)
  - RequestForm 모델: 사용자가 제출한 신청서
  - RequestFormAttachment 모델: 첨부파일 관리 (Active Storage 연동)
  - RequestTemplateApprovalRule 모델: 템플릿별 승인 규칙

- **주요 기능 구현**
  - Polymorphic 관계 준비 (기존 승인 시스템과 통합 예정)
  - JSON 직렬화로 동적 폼 데이터 저장
  - 필드 타입별 검증 규칙 및 옵션 관리
  - 템플릿 버전 관리 및 복사 기능
  - 자동 번호 생성 (REQ-YYYYMM-0001 형식)

- **Task Master 진행 상황**
  - Task 41 완료 (데이터베이스 모델 생성)
  - 다음 작업: Task 42 (카테고리 관리 기능 구현)
  - 전체 진행률: 70.83% (48개 작업 중 34개 완료)

## 2025-08-27

### 회의실 예약 시스템 UI/UX 개선

#### 캘린더 뷰 개선
- **예약 카드 정보 표시 개선**
  - 15분 예약: 이름만 표시
  - 30분 예약: 이름, 시간 표시
  - 45분 이상: 이름, 시간, 목적 모두 표시
  - 짧은 예약도 최소한 예약자 이름은 표시되도록 개선

- **날짜 네비게이션 개선**
  - 좌우 화살표 버튼을 왼쪽에 나란히 배치 (사용성 향상)
  - 요일 표시 한국어로 변경 (월화수목금토일)
  - "오늘로 이동" 버튼 조건부 표시 (오늘이 아닌 날짜에서만 표시)
  - 버튼 위치 고정으로 날짜 표시 위치 일관성 유지

- **캘린더 시간 범위 조정**
  - 18:00 시간대 제거 (예약 종료 시간이므로 불필요)
  - 9:00-17:45까지만 표시

#### 모달 기능 통합
- **통합된 예약 모달**
  - "예약하기" 버튼, 수정 버튼, 드래그앤드롭 모두 동일한 모달 사용
  - showModal 함수로 통합 (new/edit 모드 지원)
  - 모달 배경 투명도 문제 해결 (overlay와 dialog 분리)

- **회의실 선택 개선**
  - 지점 필터 적용 시에도 모달에서 모든 회의실 선택 가능
  - @all_rooms 데이터로 전체 회의실 목록 제공

#### 에러 메시지 개선
- **예약 충돌 에러 표시**
  - JSON 형태 에러를 사용자 친화적 메시지로 변환
  - "예약 수정 실패 - 해당 시간에 이미 예약이 있습니다" 형태로 표시

#### 버튼 추가
- **내 예약 보기 버튼**
  - 캘린더 페이지에서 내 예약 리스트로 이동 가능
  - 예약하기 버튼 옆에 배치

---

## 2025-08-26 (추가 작업)

### 회의실 예약 시스템 설계
- **회의실 예약 시스템 PRD 작성**
  - 경비 관리 시스템에 통합될 회의실 예약 기능 설계
  - 필수 기능에 집중한 간소화된 버전 작성
  - 일간 캘린더 뷰 중심의 예약 시스템
  - 드래그 앤 드롭 인터페이스 계획
  
### Task Master 상태 정리
- **완료된 작업 상태 업데이트**
  - Task 26: 검증 Job 구현 → done (ValidationJob 이미 구현됨)
  - Task 28: AI 분석 결과 표시 기능 → done (뷰 파일들 이미 구현됨)
  - Task 34.1: Solid Queue 설정 → done (config/recurring.yml 설정 완료)

---

## 2025-08-26

### 완료된 작업

#### AI 검증 결과 영구 저장 기능
- **ValidationHistory 테이블 확장**
  - full_validation_context JSON 컬럼 추가 마이그레이션
  - Rails 캐시 만료 후에도 AI 검증 결과 4개 섹션 모두 표시 가능
  - Symbol/String 키 호환성 문제 해결 (HashWithIndifferentAccess 적용)

#### 제출된 경비 시트 상세 보기 기능
- **제출 내역 확인 버튼 및 페이지 추가**
  - submission_details 액션 및 뷰 구현
  - 제출 취소 버튼 옆에 "제출 내역 확인" 버튼 배치
  - AI 검증 결과와 첨부서류 상세 내용 표시
  - 법인카드 명세서 거래 내역 테이블 형태로 표시

#### 관리자 페이지 개선
- **AttachmentRequirements 컨트롤러 수정**
  - Admin::BaseController 상속으로 변경
  - 관리자 GNB가 올바르게 표시되도록 수정
  - admin 레이아웃에 "첨부파일AI" 메뉴 추가

#### UI 개선
- **메뉴명 간소화**
  - 일반 사용자 네비게이션: "경비 시트" → "경비"
  - 모바일/데스크톱 메뉴 모두 적용

---

## 2025-08-25

### 완료된 작업

#### AI 검증 시스템 개선
- **Symbol/String 키 호환성 문제 해결**
  - HashWithIndifferentAccess 사용으로 캐시 데이터 접근 문제 해결
  - 영수증 누락 감지 정상 작동

- **영수증 필요 항목 정렬 로직 개선**
  - Gemini 프롬프트에 정렬 순서 명시
  - 자동 재조정 로직 추가 (통신비 → 법인카드 → 영수증 필요 항목)

- **검증 결과 표시 UI 개선**
  - 중복 내용 제거 및 5개 섹션으로 재구성
  - 4단계 완료 시 Turbo Stream으로 실시간 업데이트

#### 관리자 페이지 AI 검증 결과 표시
- **관리자 경비 시트 상세 페이지 개선**
  - AI 검증 결과를 접을 수 있는 섹션으로 추가
  - 경비 항목 목록 위에 배치하여 접근성 향상
  - HTML5 details 태그로 JavaScript 없이 구현

---

## 2025-08-22

### 완료된 작업

#### 1. 관리자 페이지 성능 및 UI 개선
- **임시저장 항목 처리**
  - 관리자 경비 시트 상세 페이지에서 임시저장 항목 제외
  
- **로깅 시스템 개선**
  - 프로덕션 환경에 멀티 로거 설정 추가
  - 파일 로거와 STDOUT 로거 동시 사용
  
- **Admin expense sheets 페이지 최적화**
  - ActiveStorage eager loading으로 N+1 쿼리 문제 해결
  - PDF 첨부파일 AI 분석 기능 추가
  
- **ExpenseSheetAttachment 기능 강화**
  - 관리자 페이지에 ExpenseSheetAttachment 표시 기능 추가
  - AI 분석 뷰를 사용자 제출 화면과 동일하게 개선
  
- **코드 리팩토링**
  - AI 분석 모달을 재사용 가능한 partial로 분리 (DRY 원칙)
  - shared/_ai_analysis_modal.html.erb 생성
  
- **UI 버그 수정**
  - 다운로드 버튼 색상 녹색으로 통일
  - Turbo 페이지 전환 시 이벤트 리스너 문제 해결

---

## 2025-08-21

### 완료된 작업

#### 1. AI 검증 시스템 안정화
- **검증 로직 개선**
  - AI 검증 단계별 실패 시 즉시 중단 로직 구현
  - 검증 데이터 추출 및 파싱 오류 수정
  - UI 단계 이름 순서 수정
  - 토큰 사용량 추적 기능 개선
  - 완전 통과가 아니면 즉시 중단하도록 로직 개선

#### 2. 임시저장 관련 버그 수정
- **경비 시트 제출 프로세스**
  - 경비 시트 취소 시 승인된 항목 체크 제거
  - AI 검증 시 임시 저장 항목 제외
  - 검증 내역 테이블에서 임시 저장 항목 완전 제거
  - 첨부파일 관련 임시 저장 오류 수정
  - 임시 저장 JavaScript 에러 수정
  - 임시저장 항목이 경비 시트 제출을 막는 문제 수정

#### 3. 검증 규칙 수정
- **경비 코드별 처리**
  - 통신비 검증 로직을 position 기준으로 수정
  - PHON 경비 코드 승인 규칙 평가 로직 수정

#### 4. 관리자 기능 강화
- **페이지 개선**
  - 경비 관리 페이지 개선 및 에러 메시지 명확화
  - 관리자 경비 시트 페이지 표시 항목 수 증가 (20→50)
  
- **승인 대시보드**
  - 전체 목록에 관련 항목만 표시하도록 필터링
  
- **엑셀 다운로드**
  - 경비 시트 엑셀 다운로드 양식 완성
  - 관리자 페이지에 전체 엑셀 다운로드 기능 추가

---

## 2025-08-20

### 완료된 작업

#### 1. AI 검증 시스템 구현
- **법인카드 명세서 AI 검증**
  - 법인카드 명세서 AI 검증 시스템 구현
  - 단계별 검증 프로세스 구축
  - Ruby 문법 오류 수정 (rescue 구문)

#### 2. 데이터 구조 표준화
- **영수증 타입 통합**
  - 영수증 타입 통합 및 JSON 스키마 표준화
  - attachment_type별 프롬프트 분리 관리

#### 3. UI/UX 개선
- **경비 시트 페이지**
  - expense_sheets index 페이지 UI 개선 및 제출 기능 통합
  - expense-sheet-submission 컨트롤러 타겟 연결 문제 수정
  - 법인카드 명세서 페이지 내용 보기 버튼 수정

---

## 2025-08-19

### 완료된 작업

#### 1. AI 분석 시스템 개선
- **법인카드 명세서 처리**
  - 법인카드 명세서 AI 분석 결과 표시 개선 (2회 커밋)
  - 테이블 형식으로 거래 내역 표시
  
#### 2. 코드 정리 및 통합
- **GeminiService 리팩토링**
  - 중복 메서드 제거 및 파싱 오류 수정
  
- **첨부파일 처리 통합**
  - ExpenseAttachment와 ExpenseSheetAttachment 동일한 흐름으로 처리
  - 코드 일관성 향상

---

## 2025-08-18 (계속)

### 추가 완료된 작업

#### 2. AI 분석 시스템 기반 구축
- **첨부파일 AI 분석 관리 시스템 통합**
  - 새로운 AI 분석 파이프라인 구축
  
- **ReceiptAnalyzer 서비스 리팩토링**
  - AttachmentRequirement 기반으로 전면 재구성
  - 더 유연한 분석 규칙 적용
  
- **Gemini 프롬프트 마이그레이션**
  - 하드코딩된 프롬프트를 시드 데이터로 완전 마이그레이션
  - 프롬프트 관리 중앙화

---

## 2025-08-18

### 완료된 작업

#### 1. 경비 시트 제출 워크플로우 개선
- **ExpenseSheetsController 오류 수정**
  - validate 메서드 이름 충돈 해결 (validate_sheet로 변경)
  - 메서드를 private 키워드 앞으로 이동하여 public action으로 접근 가능하게 수정
  
- **제출 버튼 UX 개선**
  - 제출 버튼을 항상 표시하되 조건에 따라 비활성화
  - 비활성화 시 이유를 명확하게 표시
  - ExpenseSheet 모델에 submission_blocked_reason 헬퍼 메서드 추가
  - pending_approval_count 메서드 추가
  
- **ExpenseSheetAttachment 통합**
  - 제출 페이지(submit.html.erb)에 ExpenseSheetAttachment 직접 통합
  - 필수 첨부 서류 체크리스트 UI 구현
  - 각 요구사항별 업로드 상태 시각적 표시 (완료/대기)
  - confirm_submit 액션에서 ExpenseSheetAttachment 처리 구현
  - 필수 첨부파일 검증 로직 추가
  
- **JavaScript 개선**
  - submit_checklist_controller.js에 실시간 파일 업로드 상태 업데이트 기능 추가
  - 파일 선택 시 UI 즉시 업데이트 (색상, 아이콘, 텍스트 변경)

## 2025-08-16 (계속)

### 완료된 추가 작업

#### 5. 조직별 경비 통계 대시보드 구현 [Task 20]
- **대화형 경비 통계 대시보드 구축**
  - 좌측 패널: 조직도 트리 구조 (30% 너비)
    - 재귀적 조직 트리 렌더링
    - 확장/축소 가능한 트리 노드
    - 각 조직별 경비 총액 표시
  - 우측 패널: 선택된 조직 상세 정보 (70% 너비)
    - 조직 경로 (breadcrumb) 표시
    - 경비 요약 통계
    - Chart.js 차트 (경비 코드별, 하위 조직별)
    - 상세 테이블

- **권한 관리 시스템**
  - 조직장 권한 체크 구현
  - 관리 조직 및 하위 조직만 볼 수 있도록 제한
  - can_view_organization? 헬퍼 메서드 구현
  - 권한 없는 접근 시 적절한 에러 메시지 표시

- **AJAX 기반 동적 데이터 로딩**
  - 조직 선택 시 AJAX로 상세 데이터 로드
  - 로딩 인디케이터 표시
  - 에러 처리 및 사용자 친화적 메시지
  - 성능 최적화를 위한 데이터 캐싱

- **Chart.js 차트 구현**
  - 경비 코드별 막대 차트
  - 하위 조직별 도넛 차트
  - 반응형 차트 디자인
  - 한국어 통화 포맷 적용
  - 차트 클릭 이벤트 처리

- **기술 스택**
  - Rails 8.0.2 컨트롤러 및 뷰
  - Stimulus.js 컨트롤러
  - Chart.js 4.4.1
  - Tailwind CSS
  - Turbo Frames

### 커밋 내역
- c4035cd: feat: [Task 20] 조직별 경비 통계 대시보드 구현

## 2025-08-16

### 완료된 작업

#### 1. 엑셀 다운로드 및 첨부파일 검증 개선
- **엑셀 내보내기 기능 개선**
  - 엑셀 다운로드 시 해당 월의 데이터만 필터링하도록 수정
  - `is_draft: false`인 항목만 엑셀에 포함
  - 파일명 형식을 `이름_월_경비.xlsx`로 표준화
  - expense_sheets/export.xlsx.axlsx 뷰 파일 수정

- **첨부파일 업로드 및 검증 시스템 개선**
  - AI 처리 상태 메시지 한글화 및 상세화
    - "AI 추출중...", "AI 분석중...", "AI 분석 완료" 등 단계별 상태 표시
  - 첨부파일 삭제 시 404 에러 처리 개선
  - 실시간 검증 트리거 메커니즘 강화
  - attachment_uploader_controller.js 리팩토링

#### 2. 경비 항목 폼 실시간 검증 및 성능 개선
- **실시간 검증 시스템 최적화**
  - 중복 검증 방지를 위한 디바운싱 적용
  - 폼 필드 변경 시 즉각적인 피드백 제공
  - 검증 상태 시각적 표시 개선

- **성능 최적화**
  - 불필요한 서버 요청 감소
  - 클라이언트 사이드 캐싱 구현
  - 검증 로직 효율성 개선

#### 3. 실시간 검증 및 결재선 검증 메시지 렌더링 문제 해결
- **결재선 검증 메시지 표시 개선**
  - 검증 실패 시 명확한 오류 메시지 표시
  - 결재선 설정 관련 안내 메시지 개선
  - 메시지 렌더링 타이밍 문제 수정

- **UI/UX 개선**
  - 검증 상태 아이콘 추가
  - 메시지 표시 애니메이션 적용
  - 사용자 친화적인 오류 안내

#### 4. 경비 시트 뷰 코드 중복 제거 및 정렬 기능 개선
- **코드 리팩토링**
  - ExpenseSheetsController의 중복 코드 제거
  - 정렬 관련 메서드 통합 및 최적화
  - DRY 원칙 적용으로 유지보수성 향상

- **정렬 기능 강화**
  - 날짜순, 금액순, 생성순, 경비코드순 정렬 지원
  - 오름차순/내림차순 토글 기능
  - 정렬 상태 유지 및 표시
  - bulk_sort_items 액션 개선으로 성능 향상

### 기술적 개선사항
- WAL 모드 관련 데이터 일관성 보장
- Turbo Frame 업데이트 최적화
- 캐시 제어 헤더 설정 개선
- 트랜잭션 처리 안정성 강화

### 코드 품질
- 에러 처리 로직 표준화
- 로깅 시스템 개선
- 테스트 커버리지 확대
- 코드 주석 및 문서화 보완

---

## 2025-08-14

### 완료된 작업

#### 경비 항목별 승인 요청 취소 기능 구현
- **구현 내용**:
  - 개별 경비 항목의 승인 요청을 취소할 수 있는 기능 추가
  - ExpenseItemsController에 `cancel_approval` 액션 추가
  - 승인 요청 취소 후 즉시 수정 가능한 상태로 변경
  - 경비 항목 편집 페이지에 "승인 요청 취소" 버튼 추가

- **데이터베이스 변경**:
  - ApprovalRequest 테이블에 `cancelled_at`, `completed_at` 컬럼 추가
  - ApprovalHistory enum에 'cancel' 액션 추가

- **기술적 세부사항**:
  - ApprovalRequest 모델에 `cancel!` 메서드 구현
  - 트랜잭션으로 안전한 상태 변경 보장
  - 승인 이력에 취소 기록 자동 생성
  - 모든 대기 중인 승인 스텝을 cancelled로 변경

#### N+1 쿼리 문제 해결
- Bullet gem 경고에 따른 불필요한 eager loading 제거
- expense_sheets#index에서 counter_cache 활용으로 성능 개선
- approval_request 관련 includes 최적화

#### 최근 사용한 결재선 자동 선택 기능
- 경비 코드 선택 시 해당 코드에서 최근 사용한 결재선 자동 선택
- radio 버튼 자동 체크 및 change 이벤트 발생
- 사용자 편의성 대폭 향상

#### 날짜 입력 UX 개선
- 날짜 검증을 실시간(change)에서 포커스 아웃(blur) 시점으로 변경
- 날짜 입력 중 불필요한 검증 팝업 방지
- 사용자가 날짜를 완전히 입력한 후에만 검증 실행

#### 경비 날짜 변경 시 시트 자동 이동
- 경비 항목의 날짜 변경 시 해당 월의 시트로 자동 이동
- 해당 월의 시트가 없으면 자동 생성
- 검증 에러 대신 자동 처리로 사용성 개선

---

## 2025-08-13

### 완료된 작업

#### recent_submission API 개선
- expense_sheet 상태와 무관하게 최근 제출 내역 조회
- 캐시 문제 해결로 항상 최신 데이터 반환
- 경비 항목 생성/수정 후 올바른 리다이렉트 경로 설정

#### 경비 코드 선택 시 자동 입력 기능 개선
- 코스트 센터 자동 입력 중복 방지
- 최근 제출 내용 자동 입력 디버깅 메시지 추가
- 경비 코드별 최근 사용 정보 정확한 로드

#### 결재선 수정 기능 버그 수정
- 결재선 수정 시 변경사항이 저장되지 않는 문제 해결
- 승인 스텝 업데이트 로직 개선

#### UI/UX 개선
- 결재선 목록 테이블 정렬 기능 추가
- 결재선 활성화/비활성화 토글 버튼 개선
- 승인 대기 목록에서 이미 처리한 항목 자동 제외

#### 프로덕션 환경 설정 개선
- 시드 데이터 프로덕션 환경 지원
- 첨부파일 검증 조건부 비활성화
- 스테이징/로컬 환경별 시드 데이터 분리

#### AI 영수증 분석 기능 개선
- 분석 상태 메시지 명확화
- 통신비 관련 프롬프트 보완
- 임시 저장 단일화 (새 임시 저장 시 기존 삭제)

#### 경비 항목 생성/수정 프로세스 개선
- 첨부파일 처리 오류 수정
- 폼 제출 프로세스 안정화
- 경비 코드 UI 개선

#### 회원가입 기능 임시 비활성화
- 프로덕션 환경 보안을 위한 조치
- 로그인 화면에서 회원가입 링크 제거

---

## 2025-08-12

### 완료된 작업

#### 시드 데이터 대규모 업데이트
- 실제 조직 구조 반영 (talenx/hunel BU 체계)
- 김영남(hunel CHA 리더), 문선주(SA Chapter 리더), 유천호(PPA Chapter 리더) 배치
- 모든 사용자 이메일을 @tlx.kr 도메인으로 통일
- 조직 계층 기반 자동 기본 결재선 생성 (67개 결재선, 212개 승인 단계)

#### 프로덕션 배포 자동화
- deploy.sh 스크립트 추가 (자동 배포 프로세스)
- 프로덕션 환경에서 시드 데이터 로드 가능하도록 수정
- 로컬 서버 시작 스크립트 이름 변경 (restart_local.sh → local.sh)

#### 결재선 관리 기능 개선
- 과도한 승인자 경고 기능 추가 (3명 이상 시 경고)
- 승인 규칙 관리 UI 개선
- 결재선 미리보기 기능 강화

#### 경비 시트 엑셀 내보내기 기능
- .xlsx 형식으로 경비 시트 내보내기 구현
- 경비 항목 상세 정보 포함
- 승인 상태 및 결재 정보 포함

#### AI 영수증 분석 기능 대폭 개선
- Gemini 2.0 Flash 모델 적용
- 구조화된 출력으로 정확도 향상
- 첨부파일 자동 요약 기능 구현
- 영수증 정보 자동 추출 및 폼 필드 자동 입력

#### 사용자 편의 기능 개선
- 경비 코드별 최근 입력 내용 자동 불러오기
- 임시 저장 기능 고도화
- 첨부파일 업로드 및 관리 개선

---

## 2025-08-11

### 완료된 작업

#### 예산 사전 입력 기능 구현 완료
- **데이터베이스 설계 및 마이그레이션**
  - `is_budget`: 예산 모드 플래그
  - `budget_amount`: 예산 금액
  - `actual_amount`: 실제 집행 금액
  - `budget_exceeded`: 예산 초과 여부
  - `excess_reason`: 예산 초과 사유
  - `budget_approved_at`: 예산 승인 타임스탬프
  - `actual_approved_at`: 실제 집행 승인 타임스탬프

- **ExpenseItem 모델 확장**
  - 예산 관련 스코프 추가 (budget_mode, actual_mode, budget_exceeded_items)
  - 예산 상태 확인 메서드 (budget_mode?, actual_input_pending?, budget_approval_completed?)
  - 예산 사용률 계산 메서드
  - 예산 초과 자동 체크 로직

- **예산 입력 UI**
  - budget-mode Stimulus 컨트롤러 구현
  - 체크박스로 예산/일반 모드 전환
  - 동적 필드 표시/숨김 처리
  - 금액 필드 자동 전환

- **예산 승인 프로세스**
  - 예산 모드 승인 시 budget_approved_at 업데이트
  - 일반 모드 승인 시 actual_approved_at 업데이트
  - 경비 목록에서 예산 항목 구분 표시 (황색 배지)

- **실제 집행 금액 입력 기능**
  - 예산 승인 완료 항목에 대한 실제 금액 입력 화면
  - actual-amount Stimulus 컨트롤러로 예산 초과 실시간 체크
  - 예산 초과 시 사유 입력 필수화
  - 경비 목록에서 실제 금액 입력 버튼 추가 (녹색 동전 아이콘)

- **예산 초과 재승인 프로세스**
  - 예산 초과 감지 시 자동으로 재승인 프로세스 시작
  - 기존 승인 요청 취소 후 새 승인 요청 생성
  - 초과 금액 및 비율 표시

### 해결된 이슈
1. 드래그드롭 알림 위치 문제 해결 - 전용 플래시 컨테이너 추가
2. 경비 코드 편집 후 리다이렉션 문제 해결 - 목록 페이지로 이동하도록 수정
3. Task Master API 키 문제 우회 - 수동 todo 리스트로 작업 진행

### 기술적 구현 사항
- Rails 콜백을 활용한 금액 자동 처리
- Stimulus 컨트롤러로 클라이언트 사이드 유효성 검사
- 트랜잭션으로 데이터 일관성 보장
- 조건부 UI 렌더링으로 사용자 경험 개선

---

## 2025-08-05

### 실시간 결재선 검증 기능 구현
- **구현 내용**:
  - 결재선 선택 시 즉시 검증 수행
  - 경비 코드나 금액 변경 시 자동 재검증
  - 검증 결과를 색상과 아이콘으로 시각적 표시 (성공/오류/정보/경고)
  - 경비 코드 버저닝 시스템과 올바르게 연동
- **기술적 세부사항**:
  - fetch API 대신 동적 폼 생성 방식으로 Turbo Stream 문제 해결
  - `form.requestSubmit()`으로 Turbo가 자동 처리하도록 함
  - 디버그 로그 추가하여 검증 과정 추적 가능
- **확인된 동작**:
  - 회식(DINE) 경비 코드는 버전 2로 0원 이상 조직총괄/조직리더/보직자 필요
  - 사용자의 결재선에 필요한 승인자가 모두 포함되어 있으면 "결재선이 승인 조건을 충족합니다" 표시

### Turbo Stream 문제 해결
- **문제**: 경비 코드 선택 시 가이드 문구와 추가 필드가 렌더링되지 않음
- **원인**: fetch API가 Turbo Stream 응답을 자동으로 처리하지 못함
- **해결**: 동적 폼 생성 후 `form.requestSubmit()` 사용하여 Turbo가 자동 처리하도록 변경
- 문서 업데이트:
  - `docs/turbo-stream-troubleshooting.md`: 케이스 2 추가 (Turbo Stream 응답 처리 문제)
  - `docs/rails8-turbo-best-practices.md`: JavaScript와 Turbo Stream 연동 패턴 추가

## 2025-08-04 (일) (계속)

### 홈 대시보드 합계 0원 문제 수정
- **문제**: 홈 대시보드에서 경비 합계가 0원으로 표시
- **원인**: ExpenseSheet의 total_amount가 제대로 업데이트되지 않음
- **해결**: 
  - ExpenseItem의 update_expense_sheet_total 메서드에서 save(validate: false) 옵션 추가
  - 모든 경비 시트의 total_amount 재계산 실행
- **결과**: 홈 대시보드에서 정확한 경비 합계 표시

## 2025-08-04 (일)

### CEO 승인 필요시 결재선 필수 검증 완료

#### 문제 상황
- 사용자가 "CEO 승인이 필요한데 결재선 없이 신청하면 안 되지"라고 지적
- 기존 코드는 결재선이 있을 때만 검증했고, 없을 때는 그냥 통과시킴

#### 해결 방법
1. `ExpenseItem#validate_approval_line` 메서드 수정
   - 승인 규칙이 트리거되는지 먼저 확인
   - 승인이 필요한데 결재선이 없으면 에러 발생
   - 필요한 승인자 그룹 정보를 에러 메시지에 포함

2. 검증 로직 순서:
   ```ruby
   # 1. 승인 규칙 트리거 확인
   triggered_rules = expense_code.expense_code_approval_rules
                                .active
                                .ordered
                                .select { |rule| rule.evaluate(self) }
   
   # 2. 승인 필요 + 결재선 없음 = 에러
   if triggered_rules.any? && approval_line_id.blank?
     errors.add(:approval_line, "승인이 필요합니다. 필요한 승인자: #{group_names}")
   end
   ```

#### 테스트 결과
- 50만원 경비: "승인이 필요합니다. 필요한 승인자: CEO, 조직리더, 보직자"
- 10만원 경비: "승인이 필요합니다. 필요한 승인자: 조직총괄, 조직리더, 보직자"
- 승인 규칙에 걸리면 반드시 결재선 선택 필요

### Task 12 완료
- 모든 결재선 검증 로직 구현 완료
- 승인 규칙과 결재선 연동 완벽히 작동

## 2025-08-04

### Task 11: 조건식 파서 및 평가 엔진 구현 ✅
- **구현 내용**:
  - ExpenseValidation::ConditionParser 클래스 구현
    - 토큰화: 필드, 연산자, 숫자, 문자열 파싱
    - AST 구성: 단순 비교 조건식 지원
    - 조건 평가: context 기반 동적 평가
  - 지원 기능
    - 연산자: >, <, >=, <=, ==, !=
    - 필드: #금액, #날짜, #커스텀필드명
    - 자동 타입 변환 (문자열→숫자)
  - ExpenseCodeApprovalRule 모델 통합
    - evaluate 메서드로 ExpenseItem 평가
    - 파싱 오류 시 false 반환 (안전한 처리)
  - 테스트
    - 다양한 연산자 테스트
    - 커스텀 필드 평가 테스트
    - 타입 변환 테스트
    - 에러 처리 테스트

### Task 10: 경비 코드별 승인 규칙 설정 기능 ✅
- **구현 내용**:
  - Admin::ExpenseCodesController 확장
    - add_approval_rule: 새 승인 규칙 추가
    - remove_approval_rule: 승인 규칙 삭제
    - update_approval_rule_order: 규칙 순서 변경 (준비됨)
  - 경비 코드 상세 페이지에 승인 규칙 섹션 추가
    - 규칙 목록 테이블 (순서, 조건식, 승인자 그룹, 상태)
    - 새 규칙 추가 폼 (조건식, 그룹 선택, 순서, 활성화)
    - Turbo Stream으로 실시간 업데이트
  - 조건식 예시 안내
    - #금액 > 300000 (30만원 초과)
    - #금액 <= 500000 (50만원 이하)
    - #참석인원 > 10 (필드 기반 조건)
    - #금액 > 0 (모든 경우)
  - 승인자 그룹 표시에 우선순위 포함

### Task 9: 승인자 그룹 관리 기능 구현 ✅
- **구현 내용**:
  - Admin::ApproverGroupsController CRUD 기능
    - 그룹 목록 (우선순위순 정렬, 페이지네이션)
    - 그룹 생성/수정/삭제 (사용 중인 그룹 삭제 방지)
    - 활성화/비활성화 토글 (Turbo Stream 지원)
  - 그룹 멤버 관리 기능
    - 멤버 추가/제거 (Turbo Stream으로 실시간 업데이트)
    - 중복 멤버 추가 방지
    - 멤버 목록에 추가자, 추가일 표시
  - 뷰 구현
    - 모달 형태의 생성/수정 폼
    - 그룹 상세 페이지에서 멤버 관리
    - 상태별 뱃지 표시 (활성/비활성, 우선순위)
  - 관리자 메뉴 업데이트
    - 승인자 그룹 관리 메뉴 카드 추가
    - 아이콘 및 설명 포함

### Task 8: 승인자 그룹 모델 및 데이터베이스 구조 설계 ✅
- **구현 내용**:
  - ApproverGroup 모델 생성
    - 그룹명, 설명, 우선순위(1~10), 활성화 여부 관리
    - 우선순위 기반 위계 시스템 구현
  - ApproverGroupMember 모델 생성
    - 승인자 그룹과 사용자 간의 다대다 관계 관리
    - 중복 멤버 방지를 위한 유니크 인덱스
  - ExpenseCodeApprovalRule 모델 생성
    - 경비 코드별 조건부 승인 규칙 관리
    - 조건식(예: #금액 > 300000)과 필수 승인자 그룹 연결
  
- **주요 기능**:
  - 승인자 그룹 우선순위 시스템
    - 상위 그룹이 하위 그룹 요구사항 자동 충족
    - higher_priority_groups 메서드로 위계 조회
  - 그룹 멤버 관리
    - add_member/remove_member 메서드
    - has_member? 확인 메서드
  - 승인 규칙 충족 확인
    - satisfied_by?: 기본 충족 확인
    - satisfied_with_hierarchy?: 위계를 고려한 충족 확인
  
- **시드 데이터**:
  - 4개 승인자 그룹 생성: CEO, 조직총괄, 조직리더, 보직자
  - 경비 코드별 승인 규칙 샘플:
    - 회식비: 금액별 단계적 승인 (30만원, 50만원 기준)
    - 출장비: 조직리더 승인 필수
    - 교육비: 10만원 초과시 보직자 승인

## 2025-08-03 (계속 - 추가 작업 2)

### 대시보드 개선 작업 ✅
- **요청 사항**: 첫 화면 대시보드를 경비 승인 시스템에 맞게 개선
- **구현 내용**:
  - 이번 달 내 경비 합계 섹션
    - 총액 표시 및 경비 코드별 세부 내역
    - 현재 월 기준 자동 계산
  - 내가 승인해야 하는 건 리스트
    - 신청자, 날짜, 경비 코드, 설명, 금액 표시
    - 상세보기 링크로 승인 페이지 이동
    - 최대 10개 표시 및 전체 보기 링크
    - 데이터가 없을 때 영역 자체 숨김
  - 내가 승인 올린 건들 리스트
    - 날짜, 경비 코드, 설명, 금액, 승인 상태 표시
    - 반려된 경우 반려자 및 사유 표시
    - 진행중인 경우 대기 중인 승인자 표시
    - 데이터가 없을 때 영역 자체 숨김
  - 조직별 경비 현황 (조직장인 경우만)
    - 직속 조직과 하위 조직의 이번 달 경비 표시
    - 전체 합계 계산 및 강조 표시
    - 경비가 없는 조직은 표시하지 않음

- **기술적 세부사항**:
  - HomeController에 필요한 쿼리 추가
  - N+1 쿼리 방지를 위한 includes 최적화
  - 반응형 그리드 레이아웃 적용 (max-w-7xl)
  - 상태별 색상 구분 및 아이콘 활용
  - 조건부 렌더링으로 불필요한 영역 숨김
  - CLAUDE.md에 DAILY_PROGRESS.md 커밋 규칙 추가

## 2025-08-03 (계속 - 추가 작업)

### Task 6.4: 프로그레스 바 및 진행 상태 시각화 ✅
- **구현 내용**:
  - 결재 진행 상황 프로그레스 바 컴포넌트 구현
  - 승인 상세 페이지에 진행률 시각적 표시
  - 경비 항목 테이블에 결재 진행률 컬럼 추가
  - 모바일 뷰에도 반응형 프로그레스 바 적용
  - Stimulus 컨트롤러로 부드러운 애니메이션 효과

- **기술적 세부사항**:
  - 전체 단계 대비 완료 단계 비율 계산 로직
  - 상태별 색상 구분 (진행중: 파란색, 승인: 녹색, 반려: 빨간색)
  - 단계별 마커로 세부 진행 상황 표시
  - Turbo Streams와 연동하여 실시간 진행률 업데이트
  - JavaScript 애니메이션으로 시각적 피드백 강화

### Task 6: UI/UX 개선 및 반응형 디자인 ✅
- **전체 완료**: 모든 서브태스크 (6.1 ~ 6.4) 성공적으로 완료
- **주요 성과**:
  - 역할별 아이콘 및 색상 시스템으로 직관적인 UI
  - 모바일 친화적인 반응형 레이아웃
  - Turbo를 활용한 실시간 UI 업데이트
  - 프로그레스 바로 결재 진행 상황 시각화

### Task 6.3: Turbo Frames/Streams를 활용한 실시간 업데이트 ✅
- **구현 내용**:
  - 승인/반려 처리 시 Turbo Stream 응답으로 실시간 UI 업데이트
  - 승인 대기 목록 자동 갱신 및 카운트 실시간 업데이트
  - 승인 타임라인 Turbo Frame으로 부분 업데이트
  - Flash 메시지를 Turbo Stream으로 표시하여 사용자 경험 개선
  - 페이지 새로고침 없이 모든 상태 변경 실시간 반영

- **기술적 세부사항**:
  - `ApprovalsController`의 approve/reject 액션에 Turbo Stream 포맷 응답 추가
  - `turbo_stream.remove`로 승인 완료된 항목 즉시 제거
  - `turbo_stream.update`로 승인 대기 카운트 실시간 갱신
  - `turbo_stream.replace`로 승인 타임라인 부분 업데이트
  - Flash 메시지용 전용 영역 추가 및 Turbo Stream prepend 활용

## 2025-08-03 (계속)

### Task 6.2: 모바일 반응형 레이아웃 구현 ✅
- **구현 내용**:
  - 결재선 목록: 데스크톱 테이블 뷰 / 모바일 카드 뷰 분리
  - 승인 대시보드: 탭 네비게이션 모바일 최적화
  - 승인/참조 목록: 모바일 전용 카드 뷰 추가
  - 승인 상세 화면: 버튼 크기 및 레이아웃 모바일 최적화
  
- **주요 변경사항**:
  - Tailwind CSS 반응형 클래스 활용 (hidden/block, sm:/md: prefix)
  - 터치 친화적인 인터페이스 구현
  - 작은 화면에서도 가독성 유지
  - 모바일에서 중요 정보 우선 표시

- **생성 파일**:
  - `app/views/approval_lines/_approval_line_card.html.erb`
  - `app/views/approvals/_approval_request_card.html.erb`
  - `app/views/approvals/_reference_request_card.html.erb`

### Task 6.1: 역할별 아이콘 및 색상 시스템 구현 ✅  
- **구현 내용**:
  - ApplicationHelper에 결재 관련 헬퍼 메서드 추가
  - IconHelper 모듈 생성하여 HeroIcon SVG 인라인 렌더링
  - 결재선 목록에 역할별 아이콘 적용
  - 승인 타임라인에 아이콘 시스템 적용
  - 승인 이력에 액션별 아이콘 표시
  - 경비 시트 목록의 결재 상태에 아이콘 추가
  
- **헬퍼 메서드**:
  - approval_role_icon/color: 역할별 아이콘과 색상
  - approval_type_icon/text: 승인 방식별 아이콘과 설명
  - approval_status_color: 결재 상태별 색상
  - approval_action_icon: 결재 액션별 아이콘

### Task 7.4: 동시성 제어 테스트 ✅
- **구현 내용**:
  - 전체 승인 필요(all_required) 방식에서 동시 승인 처리 테스트
  - 단일 승인 가능(single_allowed) 방식에서 첫 번째 승인만 유효 테스트
  - 중복 승인 방지 메커니즘 테스트
  - 다단계 승인에서 순서 보장 테스트
  - 반려 시 동시성 제어 테스트
  
- **주요 변경사항**:
  - ApprovalRequest 모델에 락(lock) 기반 동시성 제어 추가
  - Thread 기반 동시성 시뮬레이션으로 경합 상황 테스트
  - single_allowed 타입에서 이미 승인된 경우 에러 처리

- **테스트 파일**: `test/integration/concurrency_control_test.rb`

## 2025-08-03 (일) - 저녁

### Task 5.1: 경비 시트 목록에 결재 상태 표시 ✅
- ExpenseSheet 모델에 결재 관련 메서드 추가
  - has_approval_items?: 결재선이 적용된 경비 항목 존재 여부 확인
  - approval_status_summary: 모든 결재 요청의 상태를 종합하여 반환
  - current_approval_step_info: 현재 대기 중인 승인자들 목록 반환
  - approval_progress_text: 사용자에게 표시할 결재 진행 텍스트 생성
- 경비 시트 목록 UI 개선
  - 상태 카드에 결재 진행 상황 추가 표시
  - 결재 상태별 색상 구분 (진행중: 파란색, 완료: 녹색, 반려: 빨간색)
  - "결재진행중 - 김영희, 박철수" 형식으로 대기 중인 승인자 표시
- 경비 항목 테이블 개선
  - 결재상태 컬럼 추가
  - 각 항목별 결재 상태를 배지로 표시
  - 결재선이 없는 항목은 "-" 표시
- 성능 최적화
  - ExpenseSheetsController의 includes에 approval_request 추가
  - N+1 쿼리 문제 방지

### Task 4.4: 승인/반려 처리 로직 모델로 리팩토링 ✅
- ApprovalRequest 모델에 처리 메서드 추가
  - process_approval: 승인 처리 로직 캡슐화
  - process_rejection: 반려 처리 로직 캡슐화
  - record_view: 참조자 열람 기록 생성
- 비즈니스 로직 개선
  - 트랜잭션으로 데이터 일관성 보장
  - ArgumentError로 권한 및 검증 오류 처리
  - 에러 메시지를 모델 errors에 추가
- ApprovalsController 리팩토링
  - approve/reject 액션을 간단하게 개선
  - 모델 메서드 호출로 중복 코드 제거
  - show 액션에서 참조자 열람 자동 기록
- 코드 재사용성 및 유지보수성 향상
  - 승인 로직을 다른 컨텍스트에서도 사용 가능
  - 테스트 작성이 더 용이한 구조

### Task 4.3: 승인 상세 화면 및 처리 기능 구현 ✅
- approvals/show.html.erb 파일 구현
  - 3열 그리드 레이아웃 (경비 정보 2열, 결재선/액션 1열)
  - 목록으로 돌아가기 링크 상단 배치
- 경비 항목 정보 표시
  - 신청자 정보 (이름, 소속)
  - 경비 코드, 금액, 경비 일자, 코스트센터
  - 설명 및 비고 표시
- 승인 이력 타임라인
  - 시간 순서대로 승인/반려/열람 이력 표시
  - 각 액션별 색상 구분 (승인=녹색, 반려=빨간색, 열람=파란색)
  - 코멘트가 있는 경우 회색 배경으로 표시
  - 처리 일시 표시
- 결재선 정보 시각화
  - 각 단계별 승인자와 현재 상태 표시
  - 현재 진행 단계 하이라이트 (파란색 배경)
  - 승인/반려 완료 단계 아이콘 표시
  - 다중 승인자 경우 승인 방식 표시
- 승인/반려 처리 UI
  - 의견 입력 textarea (승인 시 선택, 반려 시 필수)
  - 승인/반려 버튼 나란히 배치
  - JavaScript로 폼 제출 시 코멘트 동적 추가
  - 반려 시 코멘트 필수 검증
- 참조자 전용 UI
  - 승인 권한이 없는 참조자에게는 정보성 메시지 표시
  - 파란색 배경의 알림 박스로 참조 상태 안내

### Task 4.2: 승인 대기 목록 화면 구현 ✅
- approvals/index.html.erb 파일 구현
  - 탭 네비게이션으로 승인 대기 목록과 참조 목록 분리
  - 각 탭에 항목 개수 표시 (배지 스타일)
  - 간단한 JavaScript로 탭 전환 기능 구현
- 승인 대기 목록 테이블
  - 신청일, 신청자, 경비 정보, 금액, 진행 상태 표시
  - 경비 코드명과 설명을 2줄로 표시
  - 진행 상태 배지 색상 구분 (pending = 노란색)
  - 상세보기 링크 제공
- 참조 목록 테이블
  - 승인 대기 목록과 동일한 구조
  - 참조자로 지정된 항목만 표시
- 빈 상태 UI
  - 각 탭별로 항목이 없을 때 친화적인 메시지 표시
  - 아이콘과 설명 텍스트 포함
- 네비게이션 메뉴 업데이트
  - 데스크톱 및 모바일 메뉴에 "승인" 링크 추가
  - 결재선과 관리자 메뉴 사이에 배치

## 2025-08-03 (일) - 오후

### Task 2.5: 메뉴 네비게이션에 결재선 메뉴 추가 ✅
- application.html.erb에서 메인 네비게이션 수정
  - 데스크톱 메뉴: 경비 시트와 관리자 메뉴 사이에 결재선 메뉴 추가
  - 모바일 메뉴: 동일한 위치에 아이콘과 함께 결재선 메뉴 추가
  - 클립보드 체크 아이콘 사용 (결재 승인 의미)
- 권한 확인
  - logged_in? 체크로 로그인한 사용자만 메뉴 표시
  - 라우팅은 이미 설정되어 있음 (resources :approval_lines)
  - ApprovalLinesController에서 require_login으로 접근 제어

### Task 2.4: 드래그 앤 드롭으로 단계 순서 변경 기능 ✅
- Sortable.js 라이브러리 importmap에 추가
  - `bin/importmap pin sortablejs` 명령어로 설치
  - SHA-384 integrity 체크섬 포함
- approval_line_form_controller.js 개선
  - Sortable 라이브러리 import 추가
  - initializeSortable() 메서드 구현
  - 드래그 종료 시 updateStepNumbers() 호출
  - 순서 변경 알림 메시지 표시 기능
- 드래그 핸들 UI 구현
  - _approval_step_fields.html.erb에 드래그 아이콘 추가
  - 호버 시 색상 변경 효과
  - cursor-move 스타일 적용
- 사용자 가이드 추가
  - 드래그 앤 드롭 기능 안내 문구
  - 드래그 핸들 아이콘 포함 설명

## 2025-08-03 (일) - 밤

### Task 7.3: 승인 프로세스 시나리오 테스트 ✅
- 승인 프로세스 전체 플로우 테스트 구현
  - 결재선 생성 → 경비 항목 적용 → 승인 처리 전체 시나리오
  - 단일 승인자 플로우 테스트
  - 다단계 승인 프로세스 테스트
  - 병렬 승인 (전체 승인 필요) 테스트
  - 단일 승인 가능 프로세스 테스트
  - 반려 시 프로세스 중단 테스트
  - 참조자 권한 테스트 (열람만 가능)
- fixture 관련 문제 해결
  - Foreign key 위반 문제로 인해 fixture 사용 제거
  - 테스트 데이터를 코드에서 직접 생성하는 방식으로 변경
  - 불필요한 fixture 파일 정리
- 간단한 승인 플로우 테스트 추가
  - 기본 승인 프로세스 테스트
  - 반려 프로세스 테스트
  - 13개의 assertion으로 주요 기능 검증

## 2025-08-03 (일) - 밤

### 시드 데이터 전면 개선 및 경비 데이터 생성 ✅
- 시드 파일의 custom_fields 중복 정의 버그 수정
  - 경비 코드별 금액 계산 로직과 필드 생성 로직 통합
  - num_attendees, num_members 변수를 참조하여 일관된 인원수 사용
  - 필드 키 정확한 매핑으로 validation 오류 해결
- 전체 사용자(68명)에게 경비 데이터 생성
  - 최근 3개월간 경비 시트 생성 (2025년 6,7,8월)
  - 각 시트당 5개의 랜덤 경비 항목 추가
  - 총 204개 경비 시트, 1022개 경비 항목 생성
- 경비 코드별 적절한 금액 및 검증 규칙 적용
  - OTME(초과근무 식대): 인당 15,000원 한도
  - PHON(통신비): 40,000원 한도
  - DINE(회식대): 인당 50,000원 한도
  - 각 코드별 required_fields에 맞는 데이터 생성
- 실제 업무와 유사한 샘플 데이터
  - 40개의 실제 업체명 사용 (스타벅스, 카카오택시 등)
  - 30개의 다양한 업무 사유 및 설명
  - 경비 코드별 특성에 맞는 custom_fields 값 생성
- 과거 경비 항목에 30% 확률로 결재선 적용 및 승인 처리
  - 기본 결재선 자동 적용
  - 승인 이력 생성으로 실제와 유사한 데이터 구조

### 시드 데이터 실제 정보로 업데이트 ✅
- 익명화된 이름을 실제 이름으로 변경
  - anonymize_name 함수 제거
  - 모든 사용자 실명 사용
- 조직 구조 재편성
  - talenx BU에서 20명을 hunel BU로 이동
  - SA Chapter와 PPA Chapter에만 배치
  - 김영남: hunel Cha 리더 (manager)
  - 문선주: SA Chapter 리더 (manager)  
  - 유천호: PPA Chapter 리더 (manager)
- 이메일 도메인 통일
  - 모든 사용자 이메일을 @tlx.kr로 변경
  - 기존 @hcg.com 도메인 제거
- 자동 기본 결재선 생성
  - 모든 사용자에게 조직 계층 기반 "기본 결재선" 생성
  - 직속 조직장 → 상위 조직장 → ... → 대표이사 구조
  - 자신이 조직장인 경우 상위 조직부터 시작
  - 총 67개 결재선, 212개 승인 단계 생성

# 일일 진행 상황

## 2025-08-04

### Task 12: 결재선 검증 로직 구현 ✅

#### 구현 내용:
1. **ApprovalLineValidator 서비스 클래스 생성**
   - `/app/services/expense_validation/approval_line_validator.rb`
   - 경비 항목의 결재선이 승인 규칙을 충족하는지 검증
   - 계층적 승인 그룹 지원 (상위 그룹이 하위 그룹 요구사항 충족)
   - 사용자 친화적인 에러 메시지 생성

2. **ExpenseItem 모델 검증 강화**
   - `before_validation :validate_approval_line` 콜백 추가
   - 결재선과 경비 시트의 결재선 일치 여부 확인
   - 승인 규칙에 따른 결재선 검증

3. **ExpenseSheet 제출 프로세스 개선**
   - `requires_approval?` 메서드: 승인이 필요한 항목 확인
   - `validate_approval_lines` 메서드: 모든 항목의 결재선 검증
   - 제출 시 결재선 검증 실패하면 상세 에러 메시지 제공

4. **데이터베이스 마이그레이션**
   - ExpenseSheet에 approval_line_id 필드 추가
   - 외래 키 제약 조건 설정

5. **테스트 작성**
   - ApprovalLineValidator 단위 테스트 (7개)
   - ExpenseSheet 통합 테스트 추가 (2개)
   - 모든 테스트 통과 확인

#### 주요 기능:
- 조건식 기반 승인 규칙 평가 (예: "#금액 > 100000")
- 계층적 승인 그룹 지원 (임원이 팀장 요구사항 충족 가능)
- 복수 승인 규칙 동시 검증
- 조건식을 한국어로 변환하여 친화적인 에러 메시지 생성

#### 해결한 문제:
- 모델 구조 차이로 인한 테스트 수정
- DashboardBroadcastService 미정의 문제 해결
- Fixture 및 테스트 데이터 중복 문제 해결

## 2025-08-03

### Task 2.3 완료: 결재선 생성/편집 폼 구현
- approval_line_form_controller.js: Stimulus 컨트롤러 구현
  - 동적 단계 추가/삭제 기능 (addStep/removeStep)
  - Choice.js를 활용한 승인자 검색 가능한 드롭다운
  - 역할 변경 시 승인 방식 필드 동적 표시/숨김
  - step_order 자동 번호 매기기 및 업데이트
  - 기존 단계 수정 시 _destroy 플래그 처리
- _form.html.erb: 결재선 폼 공통 partial
  - 기본 정보 섹션 (이름, 활성화 체크박스)
  - 승인 단계 섹션 (동적 추가/삭제)
  - 템플릿 태그를 활용한 새 단계 추가
  - 폼 검증 에러 메시지 표시
- _approval_step_fields.html.erb: 개별 승인 단계 필드
  - 3열 그리드 레이아웃 (승인자/역할/승인방식)
  - Choice.js 초기화를 위한 데이터 속성
  - 조건부 승인 방식 선택 (같은 단계 다중 승인자)
- new/edit.html.erb: 생성 및 수정 페이지
  - 일관된 레이아웃과 네비게이션
  - 폼은 Turbo 비활성화 (Choice.js 호환성)

### Task 2.2 완료: 결재선 목록 및 상세 화면 구현
- index.html.erb: 결재선 목록 페이지 구현
  - 활성/비활성 결재선 분리하여 표시
  - 반응형 그리드 레이아웃 (md:grid-cols-2 lg:grid-cols-3)
  - 결재선이 없을 때 친화적인 빈 상태 UI
- _approval_line.html.erb: 재사용 가능한 결재선 카드 컴포넌트
  - Turbo Frame으로 감싸서 비동기 업데이트 지원
  - 승인 단계 수와 승인자 목록 표시
  - 활성/비활성 상태 뱃지 및 토글 버튼
  - 수정/삭제 액션 버튼 (삭제는 Turbo 비활성화)
- show.html.erb: 결재선 상세 정보 페이지
  - 단계별 승인자 정보 카드 형태로 표시
  - 각 단계의 역할, 승인방식, 소속 정보 표시
  - 사용 현황 통계 대시보드 (진행중/승인완료/반려 건수)
  - 사용 중인 결재선 삭제 방지를 위한 정보 표시

### Task 2.1 완료: ApprovalLinesController 생성
- 결재선 CRUD를 위한 컨트롤러 생성 (rails generate controller)
- 모든 RESTful 액션 구현:
  - index: 활성/비활성 결재선 분리 표시
  - show: 결재선 상세 정보 및 승인 단계 표시
  - new/create: 새 결재선 생성
  - edit/update: 기존 결재선 수정
  - destroy: 결재선 삭제 (사용 중인 경우 삭제 방지)
- toggle_active 액션 추가:
  - Turbo Stream으로 비동기 활성/비활성 전환
  - partial 업데이트로 화면 새로고침 없이 처리
- 보안 및 권한 관리:
  - require_login으로 로그인 사용자만 접근
  - check_owner로 본인 결재선만 수정/삭제 가능
- nested attributes 지원:
  - approval_line_steps_attributes 허용
  - ApprovalLine 모델에 accepts_nested_attributes_for 추가
- 라우팅 설정: resources :approval_lines with toggle_active member route

### Task 1.5 완료: 모델 관계 설정 및 validation 추가 (Task 1 완료)
- User 모델에 결재선 관련 관계 추가:
  - has_many :approval_lines (사용자가 생성한 결재선)
  - has_many :approval_line_steps (승인자로 지정된 단계)
  - has_many :approval_histories (승인 이력)
- ExpenseItem 모델에 has_one :approval_request 관계 추가
- 각 모델에 유용한 인스턴스 메서드 추가:
  - ApprovalLine: total_steps, has_approver?, duplicate_for_user (결재선 복사)
  - ApprovalLineStep: role_display, approval_type_display, 단계 재정렬 콜백
  - ApprovalRequest: progress_percentage, can_be_approved_by?, pending_approvers
  - ApprovalHistory: action_display, role_display, summary
- references 스코프를 referrers로 변경 (Rails 예약어 충돌 해결)
- ApprovalRequest 마이그레이션 파일 수정 (중복 인덱스 오류 해결)
- 마이그레이션 실행 및 데이터베이스 스키마 적용 완료
- 샘플 결재선 시드 데이터 추가:
  - 기본 결재선 (1단계)
  - 2단계 결재선 (팀장 → 부서장)
  - 병렬 승인 결재선 (전체 승인 필요)
  - 참조자 포함 결재선
  - 선택적 승인 결재선 (단일 승인 가능)
- **Task 1 (결재선 모델 및 데이터베이스 구조 설계) 완료**

### Task 1.4 완료: ApprovalHistory 모델 생성
- 승인/반려 이력을 저장하는 ApprovalHistory 모델 생성
- 필수 필드: approval_request_id, approver_id(User 참조), step_order, role, action, approved_at
- action enum 정의: approve(승인), reject(반려), view(열람/참조자)
- role enum 정의: approve(승인), reference(참조) - 단계별 역할 구분
- 반려 시 comment 필수 validation 추가
- after_create 콜백으로 ApprovalRequest 상태 자동 업데이트:
  - 반려 시 전체 프로세스 중단 (status: 'rejected')
  - 승인 시 다음 단계 진행 또는 완료 처리
  - 참조자 열람은 상태 변경 없음
- 유니크 인덱스로 중복 처리 방지 (approval_request_id, approver_id, step_order)
- 스코프 추가: ordered, approvals, rejections, for_step
- approved_at 인덱스와 action 인덱스 추가로 조회 성능 최적화

### Task 1.3 완료: ApprovalRequest 모델 생성
- 경비 항목별 승인 요청을 관리하는 ApprovalRequest 모델 생성
- 필수 필드: expense_item_id, approval_line_id, current_step(기본값 1), status(기본값 'pending')
- status enum 정의: pending(진행중), approved(승인완료), rejected(반려), cancelled(취소)
- expense_item_id 유니크 인덱스로 중복 승인 요청 방지
- 승인 프로세스 관련 메서드:
  - can_proceed_to_next_step?: 다음 단계 진행 가능 여부 확인
  - current_step_approval_type: 현재 단계의 승인 방식 반환
  - current_step_approvers: 현재 단계의 승인자 목록
- 스코프 추가: in_progress, completed, for_approver

### Task 1.2 완료: ApprovalLineStep 모델 생성
- 결재선 단계별 승인자 정보를 저장하는 ApprovalLineStep 모델 생성
- 필수 필드: approval_line_id, approver_id(User 참조), step_order, role
- role enum 정의: approve(승인), reference(참조)
- approval_type enum 정의: all_required(전체 승인 필요), single_allowed(단일 승인 가능)
- 인덱스 추가:
  - approval_line_id와 step_order 복합 인덱스
  - approval_line_id, approver_id, step_order 유니크 복합 인덱스 (같은 단계 중복 방지)
- 커스텀 검증: 같은 단계에 승인자가 여러 명일 때만 approval_type 필수
- 스코프 추가: ordered, approvers, references, for_step

### Task 1.1 완료: ApprovalLine 모델 생성
- 결재선 마스터 정보를 저장하는 ApprovalLine 모델 생성
- 필수 필드: user_id(소유자), name(결재선 이름), is_active(활성화 여부)
- user_id와 name의 유니크 복합 인덱스 추가로 중복 방지
- is_active 필드 기본값 true 설정
- 관계 설정:
  - belongs_to :user
  - has_many :approval_line_steps, dependent: :destroy
  - has_many :approval_requests, dependent: :restrict_with_error
- validation 추가: name 필수 및 유저별 유니크
- 스코프 추가: active, for_user

### 결재선 시스템 개발 계획 수립
- Task Master를 활용한 체계적인 개발 계획 수립
- 결재선 시스템 PRD 작성 및 수정
  - "합의" 용어를 제거하고 승인 방식(전체 승인 필요/단일 승인 가능)으로 정리
  - 승인/참조 역할 명확히 구분
- Task Master로 PRD 파싱 및 태스크 생성
  - 총 7개 주요 태스크 생성
  - 31개 서브태스크로 세분화
  - 의존성 관계 설정 완료
- .taskmaster 폴더를 Git 저장소에 추가
  - .gitignore에서 제외 처리
  - 팀 협업을 위한 프로젝트 정보 공유 가능

### 경비 한도를 계산식 방식으로 설정 기능 구현
- limit_amount 필드를 문자열로 변경하여 동적 수식 지원
- 참가자 수, 숫자 필드 등을 활용한 계산식 설정 가능 (예: #구성원 * 15000)
- 필드명 변경 시 한도 수식과 설명 템플릿 자동 업데이트
- 한도 계산 검증 로직 추가 및 실시간 계산 적용
- 마이그레이션 파일 생성: `20250803000557_change_limit_amount_to_string_in_expense_codes.rb`
- 마이그레이션 파일 생성: `20250803001119_update_expense_code_field_keys_to_korean.rb`

### 관리자 페이지 UI/UX 개선
- 경비코드/코스트센터 생성/수정 폼을 모달에서 일반 페이지로 변경
- /new, /edit URL 직접 접근 가능하도록 라우팅 수정
- 다른 관리자 메뉴와 일관된 인터페이스 제공

### ExpenseSheet enum 메서드명 오류 수정 및 favicon 추가
- enum prefix: true로 인한 메서드명 변경 (submitted? → status_submitted?)
- 콘솔 에러 해결을 위한 favicon.ico 파일 추가

### Rails 8 Turbo 리다이렉트 문제 근본적 해결
1. **ApplicationController redirect_to 메서드 오버라이딩**
   - Turbo/HTML 요청 시 자동으로 status: :see_other 적용
   - 개발자가 일반 redirect_to 사용해도 자동으로 Turbo 호환
   - 기존 Rails 코드와 100% 호환성 유지

2. **turbo_redirect_to 헬퍼 메서드 추가**
   - 모든 리다이렉트에서 status: :see_other 자동 적용
   - ExpenseItemsController의 복잡한 respond_to 블록 제거
   - config/initializers/turbo.rb 추가로 폼 기본 동작 설정

3. **Turbo/Stimulus 사용 정책 문서화**
   - 일관된 Turbo 사용 가이드라인 정립
   - Stimulus 컨트롤러 네이밍 및 역할 정의
   - 현재 작동 중인 패턴 보존 명시
   - CLAUDE.md에 정책 문서 참조 추가

### 경비 시트/항목 입력 인터페이스 개선
1. **Choice.js 라이브러리 도입으로 멀티셀렉트 UI/UX 개선**
   - 검색 가능한 드롭다운 구현
   - 선택된 항목 태그 형태로 표시
   - 수정 모드에서 기존 데이터 자동 복원

2. **경비 항목 작업 후 리다이렉트 경로 통일**
   - 모든 CRUD 작업 후 /expense_sheets로 이동
   - 개별 경비 시트 상세 페이지(/expense_sheets/:id) 제거
   - 취소 버튼 경로도 통일

3. **UI 레이아웃 개선**
   - 경비 항목 추가 버튼을 테이블 하단으로 이동
   - 삭제 기능 Turbo 비활성화로 안정성 향상

4. **성능 최적화**
   - 불필요한 organization eager loading 제거
   - Bullet gem 경고 해결

## 2025-08-02

### 관리자 페이지 및 경비 시트 전체 UI/UX 개선

#### 주요 변경사항
- Tremor 디자인 시스템 전면 적용
- 경비 항목 추가/수정 폼 Tremor 디자인 적용
- 모든 관리자 페이지 레이아웃 통일 (여백, 타이틀 크기 표준화)
- 테이블 작업 버튼을 아이콘 스타일로 통일
- 상세 페이지 구조 개선 (제목을 카드 외부로 이동)
- 레이아웃 시프트 문제 해결 (스크롤바 및 Turbo 설정)
- Admin::MenuController가 Admin::BaseController 상속하도록 수정

#### 세부 변경사항
1. **사용자 관리**: 리스트, 상세, 편집 페이지 Tremor 적용
2. **조직 관리**: 전체 페이지 Tremor 적용 및 아이콘 버튼화
3. **코스트센터 관리**: 상세 페이지 구조 개선
4. **경비코드 관리**: 상세 페이지 구조 개선 및 캐시 문제 해결
5. **경비시트 관리**: 관리자 전용 페이지 분리
6. **마감 대시보드**: Tremor 컴포넌트로 전환
7. **경비 항목 입력 폼 개선**

### 관리자 페이지 상세 화면 버튼 아이콘 스타일 통일
1. **사용자 상세 페이지**
   - 편집, 삭제, 목록으로 버튼을 아이콘만 표시하는 스타일로 변경
   - 각 버튼에 `title` 속성 추가로 툴팁 지원
   - 일관된 호버 효과 및 패딩 적용

2. **조직 상세 페이지**
   - 편집, 삭제, 목록으로 버튼을 아이콘 스타일로 변경
   - 기존 텍스트 버튼에서 아이콘 전용 버튼으로 전환

3. **관리자 경비 시트 상세 페이지**
   - "목록으로" 버튼을 아이콘 스타일로 변경
   - 다른 상세 페이지와 일관된 스타일 유지

4. **경비 코드 상세 페이지**
   - "목록으로" 버튼을 아이콘 스타일로 변경
   - `inline-block` 클래스 추가로 적절한 정렬 유지

5. **통일된 아이콘 버튼 스타일**
   - 편집: 연필 아이콘
   - 삭제: 휴지통 아이콘 (호버 시 빨간색)
   - 목록으로: 왼쪽 화살표 아이콘
   - 모든 버튼에 `p-2 rounded-lg hover:bg-gray-100 transition-colors group` 적용

## 2025-08-02

### 관리자 페이지 스타일 통일 및 레이아웃 시프트 문제 해결
1. **문제 식별 및 해결**
   - 경비코드 관리와 마감 대시보드 페이지 전환 시 레이아웃이 미세하게 이동하는 문제 발견
   - 원인: 페이지별 콘텐츠 높이 차이로 인한 스크롤바 표시/숨김
   - 해결: `html { overflow-y: scroll; }` CSS 추가로 스크롤바 항상 표시

2. **Turbo 설정 정리**
   - 경비코드 관리 페이지의 불필요한 Turbo 캐시 메타 태그 제거
   - 마감 대시보드의 월 선택 폼에서 Turbo Frame 대신 전체 페이지 새로고침 사용
   - 페이지 전환 시 일관된 동작 보장

3. **레이아웃 구조 통일**
   - 모든 관리자 페이지의 헤더 구조를 동일하게 통일
   - 컨테이너: `max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6`
   - 타이틀: `text-2xl font-semibold`
   - 테이블 작업 버튼: 아이콘 스타일로 통일

4. **누락된 아이콘 버튼 적용**
   - 경비 시트 관리 페이지의 '보기' 버튼을 아이콘으로 변경
   - 조직 관리 페이지의 하위 조직 표시 부분에서도 텍스트 버튼을 아이콘으로 변경
   - 하위 조직의 들여쓰기를 인라인 스타일로 적용 (Tailwind의 동적 클래스 제한 회피)

5. **관리자 페이지 상세보기/수정 폼 Tremor 디자인 적용**
   - 사용자 관리: 상세보기, 편집 페이지 Tremor 디자인 적용
   - 조직 관리: 상세보기, 편집, 새 조직 페이지 Tremor 디자인 적용
   - 코스트센터 관리: 폼 컴포넌트 Tremor 디자인 적용
   - 모든 페이지에서 일관된 레이아웃과 스타일 유지
   - 폼 필드를 그리드 레이아웃으로 정리하여 가독성 향상

## 2025-08-01 (저녁)

### 관리자 메뉴 및 경비 시트 관리 개선
- 관리자 메뉴 내비게이션을 상단 네비게이션 방식으로 통일
  - 네비게이션 순서: 조직 관리 → 사용자 관리 → 코스트센터 관리 → 경비코드 관리 → 경비시트 관리 → 마감 대시보드
  - 통계 대시보드 기능 제거 (사용하지 않는 기능)
  - 각 관리 페이지에 admin 레이아웃 적용
- 경비 시트 전체 리스트 기능을 관리자 메뉴로 이동
  - Admin::ExpenseSheetsController 생성
  - 일반 사용자(관리자 포함)는 자신의 경비 시트만 볼 수 있도록 변경
  - 관리자용 경비 시트 목록을 테이블 형태로 구현
  - 상태별 필터링 기능 및 통계 정보 표시
- N+1 쿼리 문제 해결
  - expense_items_count counter_cache 추가
  - includes에서 expense_items 제거하여 성능 개선
  - total_amount 컬럼 사용으로 N+1 방지
- UI 개선
  - 경비 시트 상태 헬퍼 메서드 추가 (expense_sheet_status_class, expense_sheet_status_text)
  - Kaminari gem 추가하여 페이지네이션 지원
  - 테이블 형태의 깔끔한 레이아웃 적용

## 2025-08-01 (오후)

### 경비 코드 관리 개선
- 경비 코드 리스트 정렬을 최초 버전 기준으로 변경
  - COALESCE를 사용하여 parent_code_id 또는 id 기준 정렬
  - 버전 2가 생성되어도 원래 위치 유지
  - Arel.sql 사용으로 Rails 보안 경고 해결
- 경비 코드 설명은 이미 여러줄 텍스트로 구현되어 있음 확인
- 경비 코드 설명 템플릿 검증 기능 추가
  - 템플릿의 #필드명이 필수 필드에 정의되어 있는지 검증
  - 한글 조사 자동 제거 (#사유로 → 사유)
  - 정의되지 않은 필드 사용 시 에러 메시지 표시

### 원화 표기 개선
- 모든 decimal 타입의 금액 컬럼을 integer로 변경
- format_currency 헬퍼로 천 단위 구분 쉼표 표시 (₩00,000 형식)
- number_to_currency 호출을 format_currency로 전체 교체
- 입력 폼의 step 값을 1로 변경하여 정수 입력만 허용

### 기타 수정사항
- 통신비(PHON) 한도를 40,000원으로 변경
- N+1 쿼리 문제 해결 확인

## 2025-08-01 (오전)

### 조직 관리 N+1 쿼리 문제 해결
- Bullet gem이 감지한 N+1 쿼리 문제 수정
- users_count counter cache 컬럼 추가 (마이그레이션)
- Organization과 User 모델에 counter_cache 설정
- OrganizationsController의 show 액션에 eager loading 추가
  - children.includes(:manager, :users)
  - users.includes(:organization, :managed_organizations)
- 뷰 파일에서 users.count 대신 users_count 사용
- 성능 개선으로 데이터베이스 쿼리 수 감소

### 경비 코드 관리 시스템 전면 개선
- 필드 타입 개선: 참석자→구성원으로 변경, 선택지 타입 추가
- 선택지 필드에 대한 동적 옵션 입력 UI 구현
- 설명 템플릿 한국어 지원 (영어 키와 한국어 레이블 모두 사용 가능)
- 경비 코드 버전 관리 및 캐싱 문제 해결
- 폼 레이아웃 개선 (2열→1열)
- 보기 화면 레이아웃 수정 및 불필요한 섹션 제거
- 리스트 정렬 방식 변경 (코드순→ID순)
- TRNS 코드에 이동수단 필드 추가
- 시드 데이터 정리 및 샘플 데이터 업데이트

### 선택지 필드 편집 시 옵션 UI 표시 문제 수정
- 편집 모드의 HTML 구조를 수정하여 옵션 입력 필드가 제대로 표시되도록 개선
- flex 레이아웃을 중첩 div로 분리하여 동적 추가되는 옵션 UI 수용
- toggleEditMode에서 editMode 내부의 typeSelect를 찾도록 수정
- 기존 선택지 필드 편집 시 옵션 목록이 표시되도록 수정

### 선택지 필드 타입 표시 버그 수정
- ExpenseCode::FIELD_TYPES 조회 시 .to_s.to_sym 체인으로 문자열->심볼 변환
- _show_content.html.erb와 _form.html.erb에서 필드 타입 표시 수정
- TRNS 코드의 이동수단 필드를 선택지 타입으로 재설정
- 모든 TRNS 버전 중 최신 버전만 활성화되도록 수정
- 이동수단 선택지: 택시, 버스, 지하철, 기차, 항공기, 자가용, 기타

### 경비 코드 수정 폼 레이아웃 개선
- 2열 그리드 레이아웃을 1열로 변경하여 좁은 모달에서도 깨지지 않도록 수정
- 코드, 이름, 설명, 한도 금액, 조직 필드를 각각 전체 폭 사용
- 필수 필드 섹션과 미리보기 섹션도 1열 배치로 변경
- 모바일 및 좁은 화면에서의 가독성 향상
- grid-cols-2 클래스 제거하고 space-y-4로 수직 간격 설정

## 2025-08-01

### 선택지 필드 타입 버그 수정
- ExpenseCode::FIELD_TYPES.invert 사용 시 심볼이 값으로 들어가는 문제 해결
- options_for_select에서 map을 사용하여 문자열 값으로 변환
- JavaScript의 문자열 비교와 일치하도록 select 옵션 값 수정
- 이벤트 위임(Event Delegation) 패턴으로 변경
- setupEventDelegation 메서드 추가하여 동적 요소도 이벤트 처리
- 개별 이벤트 리스너 대신 부모 요소에서 이벤트 위임 처리
- Turbo 모달에서 동적으로 로드되는 요소의 이벤트 문제 해결
- 기존 필드 편집 시 선택지 타입인 경우 옵션 입력 UI 자동 표시
- toggleEditMode에서 선택지 타입 체크 후 옵션 UI 표시
- 필드 데이터에 options 속성을 data-options로 DOM에 저장
- show 페이지에서 선택지 옵션 표시 개선

### ExpenseCode 버전 관리 버그 수정
- create_new_version! 메서드의 버전 계산 로직 수정
- versions 관계 대신 직접 쿼리로 최대 버전 조회
- "이미 존재하는 버전입니다" 오류 해결
- ExpenseCode.where(code: code).maximum(:version) 사용
- ensure_unique_code_version 메서드 수정: 자기 자신 제외하고 중복 검사
- 업데이트 시 버전 충돌 방지를 위한 reload 추가

### 경비 코드 리스트 캐시 문제 해결
- Turbo Drive 캐시로 인한 구 버전 표시 문제 수정
- ExpenseCodesController에 캐시 제어 헤더 추가
- index 페이지에 turbo-cache-control 메타 태그 추가
- force_turbo_reload 메서드 사용하여 업데이트 후 강제 리로드
- 리스트에 버전 번호 표시 추가 (디버깅용)

### 경비 코드 상세 페이지 캐시 문제 해결
- show 액션에도 캐시 제어 헤더 추가
- show.html.erb에 turbo-cache-control 메타 태그 추가
- 상세 페이지를 Turbo Frame으로 감싸서 자동 업데이트 지원
- 버전 번호 표시 추가 (디버깅용)
- show 페이지에서 수정 시 적절한 Turbo Stream 응답 반환
- _show_content.html.erb partial 생성하여 내용 분리

### 경비 코드 리스트 UI 정리
- 리스트 화면에서 수정/삭제 버튼 제거
- "보기" 버튼만 남겨서 UI 단순화
- 수정/삭제는 상세 페이지에서만 가능하도록 변경

## 2025-08-01

### 경비 코드 리스트 UI 개선
- 리스트에 필수 필드 개수 표시 컬럼 추가
- 상세 페이지에서 선택지 타입의 옵션 목록 표시
- TRNS 코드에 "이동수단" 필드 추가 성공 (버전 9로 저장됨)

### ExpenseCodesController strong parameters 버그 수정
- validation_rules 파라미터를 permit에 추가
- Unpermitted parameter 경고 해결
- 경비 코드에 필드 추가/수정 시 발생하던 문제 해결

### 샘플 데이터 시드 파일 버그 수정
- 한글 필드 키를 영문 필드 키로 변경 (참석자명 → participants 등)
- 새로운 경비 코드 validation_rules 구조에 맞게 업데이트
- 모든 custom_fields를 새로운 필드 키 형식으로 변경
- db:seed 실행 시 발생하는 검증 오류 해결

### 필드 타입 개선 및 선택지 타입 추가
- '참석자' 타입을 '구성원'으로 명칭 변경
- 새로운 '선택지' 필드 타입 추가
- 선택지 타입 선택 시 옵션 입력 UI 자동 표시
- 쉼표로 구분된 선택지 목록 입력 지원 (예: 승인, 반려, 보류)
- 미리보기와 실제 폼에서 select 드롭다운으로 렌더링
- 시드 파일 업데이트 및 기존 데이터 마이그레이션
- rake expense_codes:update_participants_label 태스크로 3개 경비 코드 업데이트

### 경비 코드 데이터 마이그레이션 완료
- 기존 배열 형태의 validation_rules를 새로운 Hash 구조로 마이그레이션
- rake expense_codes:migrate_validation_rules 태스크 생성
- 10개 경비 코드 모두 성공적으로 마이그레이션
- 각 필드에 label, type, required, order 속성 추가
- 필드 타입 자동 추론 (text, number, participants, organization)
- 필드 키를 영문으로 표준화 (참석자명 → participants, 출발지 → departure 등)
- 시드 파일(003_expense_codes.rb)도 새로운 형식으로 업데이트
- description_template의 플레이스홀더도 새 필드 키로 변경

### Task 4.4 완료: 모바일 반응형 디자인 개선
- 필드 행을 모바일에서 세로 정렬로 변경 (flex-col sm:flex-row)
- 미리보기 그리드 브레이크포인트를 xl로 조정
- 액션 버튼에 flex-shrink-0 적용하여 압축 방지
- 편집 모드에서도 반응형 레이아웃 적용
- 모바일 기기에서 더 나은 사용성 제공

### Task 4.3 완료: 알림 및 피드백 시스템 구현
- showNotification 메서드 추가로 사용자 알림 표시
- 저장/삭제 성공 시 시각적 피드백 제공
- 3초 후 자동으로 사라지는 알림 구현
- 성공/오류 상태에 따른 색상 구분

### Task 4.2 완료: 터치 이벤트 지원 추가
- 모바일 디바이스를 위한 터치 이벤트 리스너 추가
- touchstart, touchmove, touchend 이벤트 처리
- 드래그 앤 드롭과 동일한 시각적 피드백 제공
- 편집 모드에서는 터치 드래그 비활성화

### Task 4.1 완료: 시각적 피드백 개선
- 드래그 시작 시 opacity 50% 적용
- 드래그 오버 시 상단에 파란색 테두리 표시
- 저장 성공 시 녹색 플래시 효과
- 삭제 확인 다이얼로그 추가

### Task 3.4 완료: 데이터 무결성 보장
- 필드 순서 자동 재정렬 로직 구현
- 중복 순서 방지 메커니즘 추가
- 편집 모드 해제 시 자동 저장 또는 취소 처리
- 새 필드 추가 시 최대 order 값 + 1 자동 할당

### Task 3.3 완료: 위/아래 화살표 버튼 구현
- moveFieldUp/moveFieldDown 메서드 구현
- 첫 번째/마지막 필드 이동 제한
- 순서 변경 후 자동 저장 및 미리보기 업데이트
- 모바일에서도 사용 가능한 대체 UI 제공

### Task 3.2 완료: 드래그 앤 드롭 기능 구현
- HTML5 native drag & drop API 활용
- handleDragStart, handleDragOver, handleDrop 메서드 구현
- 드래그 중 시각적 피드백 제공
- 편집 모드에서는 드래그 비활성화

### Task 3.1 완료: UI에 순서 변경 컨트롤 추가
- 드래그 핸들 아이콘 추가 (draggable="true")
- 위/아래 이동 화살표 버튼 추가
- 모바일 친화적인 터치 인터페이스 고려
- 편집 모드와 일반 모드 구분

### Task 2.4 완료: 미리보기 실시간 업데이트
- updatePreview 메서드 확장하여 편집 내용 반영
- 필드 레이블, 타입, 필수 여부 변경 시 즉시 반영
- 순서 변경도 미리보기에 즉시 반영

### Task 2.3 완료: 편집/저장/취소 버튼 구현
- toggleEditMode: 읽기/편집 모드 전환
- saveField: 변경사항 저장 및 서버 동기화 없이 로컬 업데이트
- cancelEdit: 원래 값으로 복원
- 각 필드별 독립적인 편집 상태 관리

### Task 2.2 완료: 인라인 편집 UI 구현
- view-mode와 edit-mode 분리
- 편집 버튼 클릭 시 인라인 편집 모드 전환
- 저장/취소 버튼 표시
- Tailwind CSS로 깔끔한 UI 구성

### Task 2.1 완료: 기존 필드 구조 분석 및 수정
- 새로운 Hash 구조 지원 (order, label, type, required 속성)
- 기존 Array 구조와의 하위 호환성 유지
- expense_code_form_controller.js에 편집 기능 추가
- 각 필드별 고유 키 할당

### Task 1.4 완료: 사용자 입력 폼 업데이트
- custom_fields.html.erb에서 limit_amount nil 체크
- "한도 없음" 표시 로직 추가
- expense_code_info.html.erb 수정 완료

### Task 1.3 완료: 백엔드 검증 로직 수정
- AmountLimitValidator에 nil 체크 추가
- limit_amount가 nil인 경우 검증 통과
- 기존 로직 영향 없이 안전하게 처리

### Task 1.2 완료: 컨트롤러 수정
- ExpenseCodesController#expense_code_params 수정
- no_limit 체크박스 값 확인 후 limit_amount nil 설정
- significant_changes? 메서드에서 nil vs 숫자 비교 로직 추가

### Task 1.1 완료: UI에 한도 없음 체크박스 추가
- expense_codes/_form.html.erb 수정
- Stimulus controller 연동
- 체크박스 선택 시 금액 필드 비활성화
- 체크 해제 시 이전 값 복원