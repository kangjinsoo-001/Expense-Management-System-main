*최종 업데이트: 2025-09-09 15:00:00 KST*

# 경비 관리 시스템 프로젝트 구조

## 프로젝트 개요

### 기술 스택
- **Backend**: Rails 8.0.2, Ruby 3.4.5
- **Frontend**: Turbo 8, Stimulus 3, Tailwind CSS 3
- **Database**: SQLite (개발/프로덕션)
- **Background Jobs**: Solid Queue
- **File Storage**: Active Storage
- **AI Integration**: Google Gemini Flash API
- **Testing**: Minitest
- **Task Management**: Task Master AI

### 프로젝트 목적
통합 경비 및 신청서 관리 시스템으로 다음 기능을 제공:
- 월별 경비 시트 관리 및 자동 검증
- 경비 항목 생성 및 영수증 첨부
- AI 기반 4단계 경비 검증 프로세스
- 다양한 업무 신청서 작성 및 제출
- 통합 다단계 결재선 승인 프로세스 (Polymorphic)
- AI 기반 영수증 자동 분석 및 요약
- 경비 코드 및 템플릿별 자동 승인 규칙
- 실시간 대시보드 및 리포팅
- 동적 폼 필드 시스템
- 조직별 경비 통계 및 추이 분석
- 경비 마감 대시보드
- 회의실 예약 시스템

### 현재 진행 상황
- Task Master 진행률: 100% (모든 주요 기능 구현 완료)
- AI 검증 시스템 구현 완료
- 경비 마감 대시보드 구현 완료
- Turbo 호환성 개선 완료
- 조직별 경비 통계 기능 구현 완료

## 핵심 도메인 모델

### 경비 관리 모델

#### ExpenseSheet (경비 시트)
- **역할**: 월별 경비 시트 관리
- **주요 필드**: 
  - `year`, `month`: 해당 년월
  - `status`: draft/submitted/approved/rejected/closed
  - `total_amount`: 총 경비 금액
  - `submitted_at`, `approved_at`: 제출/승인 시각
  - `rejection_reason`: 반려 사유
- **관계**:
  - belongs_to :user, :organization
  - has_many :expense_items
  - has_many :pdf_attachments (Active Storage)
  - has_many :pdf_analysis_results

#### ExpenseItem (경비 항목)
- **역할**: 개별 경비 항목 관리
- **주요 필드**:
  - `expense_date`: 경비 사용일
  - `amount`: 금액
  - `description`: 설명
  - `position`: 정렬 순서
  - `is_valid`: 검증 상태
  - `custom_fields`: JSONB로 저장되는 커스텀 필드
  - `is_draft`: 임시 저장 여부
  - `budget_mode`: 예산 모드
  - `actual_amount`: 실제 사용 금액
- **관계**:
  - belongs_to :expense_sheet, :expense_code
  - has_one :approval_request
  - has_many :expense_attachments

#### ExpenseCode (경비 코드)
- **역할**: 경비 분류 및 승인 규칙 정의
- **주요 필드**:
  - `code`, `name`: 코드 및 이름
  - `limit_amount`: 한도 금액 (수식 가능)
  - `required_fields`: 필수 입력 필드 정의
  - `validation_rules`: 검증 규칙
  - `display_order`: 표시 순서
  - `description_template`: 설명 템플릿
  - `version`: 버전 관리
- **관계**:
  - has_many :expense_code_approval_rules
  - has_many :expense_items
  - belongs_to :parent_code (버전 관리용)

### 결재선 모델 (Polymorphic - 공통 사용)

> **⚠️ 중요 주의사항**
> - 결재선 모델은 **여러 도메인에서 공통으로 사용하는 Polymorphic 모델**입니다
> - 경비 항목(ExpenseItem), 신청서(RequestForm) 등 다양한 모델이 이 결재선을 공유합니다
> - **절대 특정 도메인 전용 결재선 모델을 별도로 만들지 마세요**
> - 한 모듈에서 일방적으로 수정하면 다른 모든 모듈에 영향을 미치므로 매우 주의해야 합니다
> - 수정이 필요한 경우 반드시 모든 사용처의 영향도를 분석한 후 진행하세요

#### ApprovalLine (결재선)
- **역할**: 사용자별 결재선 템플릿 관리
- **주요 필드**:
  - `name`: 결재선 이름
  - `is_active`: 활성 상태
  - `is_default`: 기본 결재선 여부
  - `description`: 설명
- **관계**:
  - belongs_to :user
  - has_many :approval_line_steps (ordered)
  - has_many :approval_requests

#### ApprovalLineStep (결재선 단계)
- **역할**: 결재선의 각 승인 단계 정의
- **주요 필드**:
  - `step_order`: 단계 순서
  - `approver_type`: 승인자 유형 (user/role)
  - `role`: 역할 (결재/합의/참조 등)
- **관계**:
  - belongs_to :approval_line
  - belongs_to :approver (User)

#### ApprovalRequest (승인 요청)
- **역할**: 경비 항목 및 신청서 승인 요청 관리 (Polymorphic)
- **Polymorphic 특성**:
  - 다양한 모델이 승인 대상이 될 수 있음
  - 현재 지원: ExpenseItem, RequestForm
  - 향후 확장 가능: 휴가신청서, 구매요청서 등
- **주요 필드**:
  - `approvable_type`: 승인 대상 타입 (ExpenseItem/RequestForm 등)
  - `approvable_id`: 승인 대상 ID
  - `status`: pending/approved/rejected
  - `current_step`: 현재 승인 단계
  - `requested_at`: 요청 시각
- **관계**:
  - belongs_to :approvable, polymorphic: true
  - belongs_to :approval_line
  - has_many :approval_histories
  - has_many :approval_request_steps

#### ApprovalHistory (승인 이력)
- **역할**: 승인/반려 이력 기록
- **주요 필드**:
  - `action`: approve/reject
  - `comment`: 승인/반려 사유
  - `processed_at`: 처리 시각
  - `step_order`: 처리 단계
- **관계**:
  - belongs_to :approval_request, :approver

### 승인자 그룹 모델

#### ApproverGroup (승인자 그룹)
- **역할**: 조직 내 승인자 그룹 관리
- **주요 필드**:
  - `name`: 그룹명
  - `group_type`: 그룹 유형 (관리자/팀장 등)
  - `is_active`: 활성 상태
  - `description`: 설명
- **관계**:
  - belongs_to :organization
  - has_many :approver_group_members
  - has_many :expense_code_approval_rules

#### ApproverGroupMember (그룹 멤버)
- **역할**: 승인자 그룹의 구성원 관리
- **주요 필드**:
  - `joined_at`: 가입일
  - `role`: 그룹 내 역할
- **관계**:
  - belongs_to :approver_group
  - belongs_to :user

#### ExpenseCodeApprovalRule (경비 코드별 승인 규칙)
- **역할**: 경비 코드별 자동 승인 규칙 정의
- **주요 필드**:
  - `condition`: 조건식 (예: "amount > 100000")
  - `order`: 승인 순서
  - `is_active`: 활성 상태
- **관계**:
  - belongs_to :expense_code, :approver_group

### 신청서 시스템 모델

#### RequestCategory (신청서 카테고리)
- **역할**: 신청서 카테고리 관리
- **주요 필드**:
  - `name`: 카테고리명
  - `description`: 설명
  - `is_active`: 활성 상태
  - `display_order`: 표시 순서
- **관계**:
  - has_many :request_templates
  - belongs_to :organization

#### RequestTemplate (신청서 템플릿)
- **역할**: 신청서 템플릿 정의
- **주요 필드**:
  - `name`: 템플릿명
  - `description`: 설명
  - `is_active`: 활성 상태
  - `display_order`: 표시 순서
  - `approval_required`: 승인 필요 여부
- **관계**:
  - belongs_to :request_category
  - has_many :request_template_fields
  - has_many :request_template_approval_rules
  - has_many :request_forms

#### RequestTemplateField (템플릿 필드)
- **역할**: 템플릿의 동적 필드 정의
- **주요 필드**:
  - `name`: 필드명
  - `field_type`: 필드 타입 (text/textarea/select/date/checkbox)
  - `is_required`: 필수 여부
  - `options`: 선택 옵션 (select 타입용)
  - `display_order`: 표시 순서
  - `placeholder`: 플레이스홀더 텍스트
- **관계**:
  - belongs_to :request_template

#### RequestTemplateApprovalRule (템플릿 승인 규칙)
- **역할**: 템플릿별 자동 승인 규칙
- **주요 필드**:
  - `condition`: 조건 (always/amount_over 등)
  - `order`: 승인 순서
  - `is_active`: 활성 상태
- **관계**:
  - belongs_to :request_template
  - belongs_to :approver_group

#### RequestForm (신청서)
- **역할**: 사용자가 작성한 신청서
- **주요 필드**:
  - `form_data`: 동적 필드 데이터 (JSONB)
  - `status`: draft/submitted/approved/rejected
  - `submitted_at`: 제출 시각
  - `approved_at`: 승인 시각
  - `rejection_reason`: 반려 사유
- **관계**:
  - belongs_to :request_template
  - belongs_to :user, :organization
  - has_many :request_form_attachments
  - has_many :approval_requests, as: :approvable

#### RequestFormAttachment (신청서 첨부파일)
- **역할**: 신청서 첨부파일 관리
- **주요 필드**:
  - `file_name`: 파일명
  - `file_size`: 파일 크기
  - `content_type`: 파일 타입
- **관계**:
  - belongs_to :request_form
  - has_one_attached :file (Active Storage)

### 회의실 예약 시스템 모델

#### RoomCategory (회의실 카테고리)
- **역할**: 회의실 카테고리 관리
- **주요 필드**:
  - `name`: 카테고리명
  - `description`: 설명
  - `display_order`: 표시 순서
  - `is_active`: 활성 상태
- **관계**:
  - has_many :rooms

#### Room (회의실)
- **역할**: 회의실 정보 관리
- **주요 필드**:
  - `name`: 회의실명
  - `category`: 구 카테고리 필드 (마이그레이션 중)
  - `room_category_id`: 카테고리 참조
- **관계**:
  - belongs_to :room_category
  - has_many :room_reservations

#### RoomReservation (회의실 예약)
- **역할**: 회의실 예약 관리
- **주요 필드**:
  - `date`: 예약 날짜
  - `start_time`: 시작 시간
  - `end_time`: 종료 시간
  - `purpose`: 사용 목적
  - `attendee_count`: 참석 인원
  - `memo`: 메모
- **관계**:
  - belongs_to :room
  - belongs_to :user
  - belongs_to :organization

### AI 및 분석 모델

#### PdfAnalysisResult (PDF 분석 결과)
- **역할**: PDF 영수증 분석 결과 저장
- **주요 필드**:
  - `attachment_id`: Active Storage 첨부 ID
  - `extracted_text`: 추출된 텍스트
  - `analysis_data`: 분석 데이터 (JSONB)
  - `card_type`: 카드 종류
  - `detected_amounts`: 감지된 금액들
  - `total_amount`: 총 금액
- **관계**:
  - belongs_to :expense_sheet
  - has_many :transaction_matches

#### TransactionMatch (거래 매칭)
- **역할**: PDF 거래 내역과 경비 항목 매칭
- **주요 필드**:
  - `transaction_data`: 거래 정보 (JSONB)
  - `confidence`: 매칭 신뢰도
  - `match_type`: 매칭 유형
- **관계**:
  - belongs_to :pdf_analysis_result
  - belongs_to :expense_item

#### ExpenseValidationHistory (경비 검증 이력)
- **역할**: AI 검증 결과 이력 관리
- **주요 필드**:
  - `validation_summary`: 전체 요약
  - `all_valid`: 전체 통과 여부
  - `validation_details`: 항목별 상세 (JSONB)
  - `issues_found`: 발견된 문제들 (JSONB)
  - `recommendations`: 권장 사항 (JSONB)
  - `step_results`: 단계별 검증 결과 (JSONB)
  - `token_usage`: AI 토큰 사용량
- **관계**:
  - belongs_to :expense_sheet
  - belongs_to :validated_by (User)

### 새로운 경비 관리 모델

#### ExpenseSheetApprovalRule (경비 시트 승인 규칙)
- **역할**: 경비 시트 전체에 대한 승인 규칙 정의
- **주요 필드**:
  - `name`: 규칙명
  - `condition`: 조건식
  - `rule_type`: 규칙 유형 (total_amount/item_count/submitter_based/expense_code_based/custom)
  - `order`: 우선순위
  - `is_active`: 활성 상태
- **관계**:
  - belongs_to :approver_group
  - belongs_to :organization

#### ExpenseSheetAttachment (경비 시트 첨부파일)
- **역할**: 경비 시트 전체 첨부파일 관리 (법인카드 명세서 등)
- **주요 필드**:
  - `file_name`: 파일명
  - `file_size`: 파일 크기
  - `content_type`: 파일 타입
  - `extracted_text`: 추출된 텍스트
  - `analysis_data`: 분석 데이터 (JSONB)
  - `status`: 처리 상태
- **관계**:
  - belongs_to :expense_sheet
  - has_one_attached :file (Active Storage)

#### ExpenseAttachment (경비 항목 첨부파일)
- **역할**: 개별 경비 항목 첨부파일 관리
- **주요 필드**:
  - `file_name`: 파일명
  - `file_size`: 파일 크기
  - `extraction_status`: 텍스트 추출 상태
  - `summary_status`: AI 요약 상태
  - `extracted_text`: 추출된 텍스트
  - `ai_summary`: AI 요약 (JSONB)
- **관계**:
  - belongs_to :expense_item
  - has_one_attached :file (Active Storage)

#### AttachmentRequirement (첨부파일 요구사항)
- **역할**: 경비 코드별 첨부파일 요구사항 정의
- **주요 필드**:
  - `required`: 필수 여부
  - `min_files`: 최소 파일 수
  - `max_files`: 최대 파일 수
  - `allowed_types`: 허용 파일 타입
  - `max_file_size`: 최대 파일 크기
- **관계**:
  - belongs_to :expense_code
  - has_many :attachment_analysis_rules
  - has_many :attachment_validation_rules

#### AttachmentAnalysisRule (첨부파일 분석 규칙)
- **역할**: 첨부파일 자동 분석 규칙
- **주요 필드**:
  - `rule_type`: 규칙 유형
  - `pattern`: 패턴 매칭
  - `extraction_fields`: 추출 필드
  - `priority`: 우선순위
- **관계**:
  - belongs_to :attachment_requirement

#### AttachmentValidationRule (첨부파일 검증 규칙)
- **역할**: 첨부파일 검증 규칙
- **주요 필드**:
  - `rule_type`: 규칙 유형
  - `condition`: 검증 조건
  - `error_message`: 에러 메시지
  - `is_active`: 활성 상태
- **관계**:
  - belongs_to :attachment_requirement

#### ExpenseClosingStatus (경비 마감 상태)
- **역할**: 조직별 월별 경비 마감 상태 관리
- **주요 필드**:
  - `year`, `month`: 해당 년월
  - `status`: 마감 상태
  - `closed_at`: 마감 일시
  - `closed_by_id`: 마감 처리자
  - `summary_data`: 요약 데이터 (JSONB)
- **관계**:
  - belongs_to :organization
  - belongs_to :closed_by (User)

## 승인/결재선 시스템 아키텍처 (Polymorphic)

### Polymorphic 승인 시스템 개요

> **핵심 원칙**: One Approval System for All

승인/결재선 시스템은 **단일 통합 시스템**으로 설계되어 있으며, 다음과 같은 특징을 가집니다:

1. **공통 모델 사용**
   - ApprovalLine, ApprovalRequest, ApprovalHistory 등 핵심 모델을 모든 도메인이 공유
   - Polymorphic association을 통해 다양한 승인 대상 지원
   - 중복 코드 제거 및 일관성 보장

2. **사용 도메인**
   - 경비 관리: ExpenseItem 승인
   - 신청서 관리: RequestForm 승인
   - 향후 확장: 휴가, 구매요청, 프로젝트 승인 등

3. **주의사항**
   - ❌ 도메인별 승인 모델 생성 금지 (예: ExpenseApproval, RequestApproval 등)
   - ❌ 특정 도메인에서 일방적인 스키마 변경 금지
   - ✅ 변경 필요 시 전체 영향도 분석 필수
   - ✅ 확장은 Polymorphic 특성을 활용하여 구현

4. **확장 방법**
   ```ruby
   # 올바른 확장 예시
   class NewModel < ApplicationRecord
     has_many :approval_requests, as: :approvable
   end
   
   # 잘못된 예시 - 별도 승인 모델 생성
   # class NewModelApproval < ApplicationRecord  # ❌ 금지
   ```

## 컨트롤러 아키텍처

### 메인 비즈니스 컨트롤러

#### ExpenseSheetsController
- **경로**: `/expense_sheets`
- **주요 액션**:
  - `index`: 월별 경비 시트 조회 (Turbo Frame 지원)
  - `show`: 경비 시트 상세 (드래그앤드롭 정렬 지원)
  - `submission_details`: 제출 상세 페이지 (AI 검증, 승인 프로세스)
  - `submit`/`confirm_submit`: 경비 제출 프로세스
  - `cancel_submission`: 제출 취소
  - `sort_items`/`bulk_sort_items`: 경비 항목 정렬
  - `attach_pdf`/`delete_pdf_attachment`: PDF 첨부 관리
  - `export`: 엑셀 내보내기
  - `validate_step`: AI 검증 단계별 실행
  - `validation_result`: 검증 결과 조회
- **특징**: 
  - Turbo 캐시 비활성화
  - position 기반 정렬
  - PDF 첨부 및 분석 지원
  - WAL 모드 최적화
  - AI 4단계 검증 프로세스 통합
  - 승인 타임라인 표시

#### ExpenseItemsController
- **경로**: `/expense_sheets/:id/expense_items`
- **주요 액션**:
  - `new`/`create`: 경비 항목 생성 (다단계 폼)
  - `edit`/`update`: 경비 항목 수정
  - `save_draft`/`restore_draft`: 임시 저장
  - `delete_draft`: 임시 저장 삭제
  - `validate_approval_line`: 결재선 검증 API
  - `recent_submission`: 최근 제출 내용 조회
  - `cancel_approval`: 승인 요청 취소
- **특징**:
  - 커스텀 필드 동적 렌더링
  - 영수증 자동 분석
  - 실시간 검증
  - 드래프트 모드 지원

### 결재 관련 컨트롤러

#### ApprovalsController
- **경로**: `/approvals`
- **주요 액션**:
  - `index`: 승인 대기 목록 (경비/신청서 통합 대시보드)
  - `show`: 승인 상세 화면 (타입별 분기 처리)
  - `approve`/`reject`: 승인/반려 처리
  - `batch_approve`: 일괄 승인
- **특징**:
  - Polymorphic 승인 지원 (ExpenseItem/RequestForm)
  - 타입별 UI 구분 (경비: 파란색, 신청서: 보라색)
  - Turbo Stream 실시간 업데이트
  - 모달 팝업 승인 UI
  - 병렬 승인 지원

#### ApprovalLinesController
- **경로**: `/approval_lines`
- **주요 액션**:
  - `index`/`show`: 결재선 목록 및 상세
  - `new`/`create`/`edit`/`update`: 결재선 CRUD
  - `reorder`: 드래그앤드롭 순서 변경
  - `preview`: 결재선 미리보기
  - `toggle_active`: 활성/비활성 토글
- **특징**:
  - SortableJS 통합
  - 실시간 미리보기

### 신청서 관련 컨트롤러

#### RequestFormsController
- **경로**: `/request_forms`
- **주요 액션**:
  - `index`: 신청서 목록
  - `new`: 신청서 작성 (카테고리/템플릿 선택)
  - `create`: 신청서 생성
  - `show`: 신청서 상세
  - `edit`/`update`: 신청서 수정
  - `destroy`: 신청서 삭제
- **특징**:
  - 다단계 폼 프로세스 (카테고리 → 템플릿 → 폼 작성)
  - 동적 필드 렌더링
  - 임시저장 기능
  - 파일 첨부 지원
  - 결재선 자동 설정

#### RequestTemplatesController
- **경로**: `/request_templates`
- **주요 액션**:
  - `index`: 템플릿 목록 (카테고리별)
  - `show`: 템플릿 상세 및 필드 정의
- **특징**:
  - 카테고리별 필터링
  - 승인 규칙 표시

#### OrganizationExpensesController
- **경로**: `/organization_expenses`
- **역할**: 조직별 경비 통계 및 추이 분석
- **주요 액션**:
  - `index`: 조직별 경비 현황 대시보드
  - `trend`: 경비 추이 분석 (월별/연도별)
  - `details`: 상세 경비 내역
  - `export`: 통계 데이터 엑셀 내보내기
- **특징**:
  - 조직 트리 네비게이션
  - 실시간 차트 업데이트
  - 하위 조직 포함/제외 옵션
  - 다양한 차트 뷰 (경비 코드별, 월별 추이, 조직별 비교)

#### ExpenseAttachmentsController
- **경로**: `/expense_attachments`
- **역할**: 경비 항목 첨부파일 관리
- **주요 액션**:
  - `create`: 첨부파일 업로드
  - `destroy`: 첨부파일 삭제
  - `summary_html`: AI 요약 HTML 렌더링
  - `upload_modal`: 업로드 모달 표시
- **특징**:
  - 드래그앤드롭 업로드
  - AI 자동 분석 트리거
  - 실시간 업로드 상태 표시

#### ExpenseSheetAttachmentsController
- **경로**: `/expense_sheet_attachments`
- **역할**: 경비 시트 전체 첨부파일 관리
- **주요 액션**:
  - `index`: 첨부파일 목록
  - `create`: PDF 명세서 업로드
  - `destroy`: 첨부파일 삭제
  - `analyze`: AI 분석 실행
- **특징**:
  - 법인카드 명세서 처리
  - 거래 내역 자동 매칭
  - 일괄 분석 기능

#### RoomReservationsController
- **경로**: `/room_reservations`
- **역할**: 회의실 예약 관리
- **주요 액션**:
  - `calendar`: 캘린더 뷰
  - `create`/`update`/`destroy`: 예약 CRUD
  - `drag_update`: 드래그앤드롭 시간 변경
  - `resize_update`: 예약 시간 조정
- **특징**:
  - 오버레이 렌더링 방식
  - 드래그앤드롭 예약 변경
  - 실시간 충돌 검사
  - Turbo Stream 업데이트

### Admin Namespace 컨트롤러

#### Admin::Closing::DashboardController
- **경로**: `/admin/closing/dashboard`
- **역할**: 경비 마감 대시보드
- **주요 액션**:
  - `index`: 조직별 마감 현황 대시보드
  - `organization_members`: 조직 구성원 경비 상태
  - `batch_close`: 일괄 마감 처리
  - `send_notifications`: 알림 발송
  - `export`: 엑셀 내보내기
- **특징**:
  - 조직 트리 브라우저 통합
  - 하위 조직 포함/제외 옵션
  - 실시간 통계 업데이트
  - 월별 네비게이션

#### Admin::ExpenseSheetsController
- **경로**: `/admin/expense_sheets`
- **역할**: 관리자용 경비 시트 관리
- **주요 액션**:
  - `index`: 전체 경비 시트 목록
  - `show`: 경비 시트 상세 (AI 검증 결과 포함)
  - `export_all`: 전체 데이터 엑셀 내보내기
- **특징**:
  - 고급 필터링 (상태, 기간, 조직, 사용자)
  - AI 검증 결과 표시
  - 일괄 처리 기능

#### Admin::ExpenseSheetApprovalRulesController
- **경로**: `/admin/expense_sheet_approval_rules`
- **역할**: 경비 시트 승인 규칙 관리
- **주요 기능**:
  - 승인 규칙 CRUD
  - 조건 빌더 UI
  - 규칙 우선순위 관리
  - 경비 코드 기반 규칙 설정
- **규칙 유형**:
  - total_amount: 총금액 조건
  - item_count: 항목수 조건
  - submitter_based: 제출자 기반
  - expense_code_based: 경비 코드 포함
  - custom: 사용자 정의

#### Admin::ExpenseCodesController
- **역할**: 경비 코드 및 승인 규칙 관리
- **주요 기능**:
  - 경비 코드 CRUD
  - 승인 규칙 설정 (add_approval_rule, remove_approval_rule)
  - 필수 필드 정의
  - 한도 금액 수식 설정
  - 승인 규칙 순서 변경
  - 드래그앤드롭 정렬

#### Admin::ApproverGroupsController
- **역할**: 승인자 그룹 관리
- **주요 기능**:
  - 그룹 CRUD
  - 멤버 추가/제거 (add_member, remove_member)
  - 그룹 활성화 관리 (toggle_active)
  - 멤버 일괄 업데이트
  - Turbo Stream 실시간 업데이트

#### Admin::AttachmentRequirementsController
- **경로**: `/admin/attachment_requirements`
- **역할**: 첨부파일 요구사항 관리
- **주요 기능**:
  - 경비 코드별 첨부 요구사항 설정
  - 분석 규칙 정의
  - 검증 규칙 설정
  - 중첩 필드 관리

#### Admin::RequestCategoriesController
- **역할**: 신청서 카테고리 관리
- **주요 기능**:
  - 카테고리 CRUD
  - 활성화 상태 관리
  - 표시 순서 조정
  - Turbo 호환 폼

#### Admin::RequestTemplatesController
- **역할**: 신청서 템플릿 관리
- **주요 기능**:
  - 템플릿 CRUD
  - 필드 정의 관리
  - 승인 규칙 설정
  - 템플릿 활성화 관리
  - 동적 필드 빌더

#### Admin::RoomCategoriesController
- **역할**: 회의실 카테고리 관리
- **주요 기능**:
  - 카테고리 CRUD
  - 활성화 상태 토글
  - 표시 순서 관리

#### Admin::RoomsController
- **역할**: 회의실 관리
- **주요 기능**:
  - 회의실 CRUD
  - 카테고리별 분류
  - 예약 현황 표시

#### Admin::GeminiMetricsController
- **역할**: AI 사용량 모니터링
- **주요 기능**:
  - 사용량 통계 조회
  - 메트릭 리셋
  - 토큰 사용량 추적

### API Namespace 컨트롤러

#### Api::ExpenseCodesController
- **역할**: 경비 코드 관련 API
- **엔드포인트**:
  - `GET /api/expense_codes/:id/fields`: 커스텀 필드 정의 조회
  - `POST /api/expense_codes/:id/validate`: 경비 항목 검증

#### Api::UsersController
- **역할**: 사용자 검색 API
- **엔드포인트**:
  - `GET /api/users/search`: 자동완성 검색
  - `GET /api/users/all`: 전체 사용자 목록

#### Api::OrganizationsController
- **역할**: 조직 검색 API
- **엔드포인트**:
  - `GET /api/organizations/search`: 조직 검색
  - `GET /api/organizations/all`: 전체 조직 목록

## 서비스 레이어

### 경비 검증 엔진 (ExpenseValidation)

#### RuleEngine
- **역할**: 경비 코드별 검증 규칙 실행
- **주요 메서드**:
  - `validate(expense_item)`: 종합 검증
  - `auto_approvable?(expense_item)`: 자동 승인 가능 여부
- **검증 항목**:
  - 필수 필드 검증 (RequiredFieldsValidator)
  - 금액 한도 검증 (AmountLimitValidator)
  - 커스텀 규칙 검증 (CustomRuleValidator)
  - 결재선 요구사항 검증 (ApprovalLineValidator)

#### ConditionParser
- **역할**: 문자열 조건식을 Ruby 코드로 파싱
- **지원 연산자**: >, <, >=, <=, ==, !=, AND, OR
- **보안**: 안전한 평가를 위한 샌드박싱
- **변수 지원**: amount, expense_date, custom_fields

### AI 서비스

#### GeminiService
- **역할**: Google Gemini API 통합
- **주요 메서드**:
  - `analyze_text(text, prompt)`: 텍스트 분석
  - `classify_receipt(text)`: 영수증 분류
  - `generate_summary(text, category)`: 카테고리별 요약
  - `analyze_for_validation(prompt)`: 경비 검증용 분석
  - `analyze_for_expense_ordering(prompt)`: 경비 항목 순서 최적화
  - `analyze_card_statement(text)`: 법인카드 명세서 분석
  - `match_transactions(statement, expenses)`: 거래 내역 매칭
- **특징**:
  - 재시도 로직 (3회)
  - 에러 핸들링
  - 사용량 추적 (GeminiMetricsService)
  - Rate limiting
  - 토큰 사용량 추적
  - 스트리밍 응답 지원

#### GeminiMetricsService
- **역할**: AI 사용량 추적 및 모니터링
- **주요 메서드**:
  - `track_usage(model, tokens)`: 사용량 기록
  - `get_monthly_usage`: 월별 사용량 조회
  - `get_daily_usage`: 일별 사용량 조회
  - `calculate_cost`: 비용 계산
- **특징**:
  - Redis 기반 카운터
  - 실시간 통계
  - 비용 추적

#### ExpenseValidationService
- **역할**: AI 기반 경비 시트 검증
- **4단계 검증 프로세스**:
  1. `validate_step_1_attachment`: 법인카드 명세서 첨부 확인
  2. `validate_step_2_telecom`: 통신비 최상단 위치 검증 및 자동 조정
  3. `validate_step_3_combined`: Gemini를 통한 카드 거래 매칭 및 재정렬
  4. `validate_step_4_receipt_check`: 개인 경비 영수증 첨부 확인
- **주요 메서드**:
  - `validate_single_step_with_context`: 단계별 실행 with 컨텍스트
  - `reorder_items_by_card_statement`: 카드 명세서 순서로 재정렬
  - `compile_final_result`: 최종 검증 결과 생성
  - `calculate_token_usage`: 토큰 사용량 계산
  - `save_validation_history`: 검증 이력 저장
- **캐싱 전략**: Rails.cache 사용 (10분 TTL)
- **특징**:
  - 비동기 처리 지원
  - 진행 상황 실시간 업데이트
  - 자동 복구 및 재시도

#### ExpenseSheetApprovalValidator
- **역할**: 경비 시트 승인 규칙 검증
- **주요 메서드**:
  - `validate(expense_sheet, approval_line)`: 승인 요구사항 검증
  - `get_required_approver_groups`: 필수 승인자 그룹 조회
  - `validate_approval_line`: 결재선 유효성 검증
  - `check_expense_codes`: 경비 코드 기반 규칙 확인
- **특징**:
  - 복합 조건 평가
  - 경비 코드 기반 검증
  - 제출자 역할 기반 검증

#### ReceiptAnalyzer
- **역할**: 영수증 분석 오케스트레이션
- **프로세스**:
  1. 텍스트 추출 (OCR/PDF)
  2. 영수증 유형 분류
  3. 카테고리별 요약 생성
  4. 주요 정보 추출
- **지원 카테고리**:
  - 식사/음식
  - 교통/주유
  - 숙박
  - 사무용품
  - 의료/약국
  - 기타

### PDF 분석 서비스

#### PdfAnalysisService
- **역할**: PDF 영수증 분석 및 매칭
- **주요 기능**:
  - PDF 텍스트 추출
  - 거래 내역 파싱
  - 경비 항목과 자동 매칭
  - 매칭 신뢰도 계산
- **프로세스**:
  - `analyze_and_parse`: 전체 분석 파이프라인
  - `extract_text_from_pdf`: PDF 텍스트 추출
  - `parse_transactions`: 거래 내역 파싱
  - `match_with_expense_items`: 항목 매칭

#### TransactionParser
- **역할**: 카드 명세서 거래 내역 파싱
- **지원 형식**:
  - 신한카드
  - 삼성카드
  - 하나카드
  - 기타 주요 카드사
- **추출 정보**:
  - 거래일시
  - 가맹점명
  - 금액
  - 승인번호

### 월 마감 서비스

#### MonthlyClosingService
- **역할**: 월별 경비 마감 처리
- **프로세스**:
  1. 미제출 시트 확인
  2. 승인 대기 항목 처리
  3. 시트 상태 마감 처리
  4. 다음 월 시트 자동 생성
- **주요 메서드**:
  - `close_month(year, month)`: 월 마감 실행
  - `validate_for_closing`: 마감 가능 여부 검증
  - `create_next_month_sheets`: 다음 월 시트 생성
  - `generate_closing_report`: 마감 리포트 생성

### 새로운 서비스

#### SheetAttachmentAnalyzer
- **역할**: 경비 시트 첨부파일 분석
- **주요 메서드**:
  - `analyze(attachment)`: 첨부파일 분석
  - `extract_transactions`: 거래 내역 추출
  - `parse_card_statement`: 카드 명세서 파싱
  - `detect_card_type`: 카드사 자동 감지
- **특징**:
  - 다양한 카드사 형식 지원
  - OCR 및 PDF 텍스트 추출
  - 거래 내역 정규화

#### SheetValidationService
- **역할**: 경비 시트 종합 검증
- **주요 메서드**:
  - `validate_sheet(sheet)`: 시트 전체 검증
  - `validate_attachments`: 첨부파일 검증
  - `validate_amounts`: 금액 검증
  - `validate_dates`: 날짜 검증
- **특징**:
  - 다단계 검증
  - 규칙 기반 검증
  - 검증 결과 캐싱

#### SimpleApprovalValidator
- **역할**: 간단한 승인 검증
- **주요 메서드**:
  - `can_approve?(user, item)`: 승인 가능 여부
  - `next_approvers(item)`: 다음 승인자 조회
  - `is_final_approver?(user, item)`: 최종 승인자 여부
- **특징**:
  - 빠른 검증
  - 캐싱 활용

#### ValidationResultHandler
- **역할**: 검증 결과 처리 및 저장
- **주요 메서드**:
  - `handle(result)`: 검증 결과 처리
  - `save_to_history`: 이력 저장
  - `notify_users`: 사용자 알림
  - `generate_report`: 리포트 생성
- **특징**:
  - 비동기 처리
  - 다중 포맷 지원
  - 실시간 알림

#### ValidationService
- **역할**: 통합 검증 서비스
- **주요 메서드**:
  - `validate_all(sheet)`: 전체 검증 실행
  - `validate_by_rules`: 규칙 기반 검증
  - `validate_by_ai`: AI 기반 검증
  - `merge_results`: 결과 병합
- **특징**:
  - 병렬 처리
  - 플러그인 구조
  - 확장 가능한 검증 체인

#### ApprovalPresenter
- **역할**: 승인 데이터 프레젠테이션
- **주요 메서드**:
  - `present(approval_request)`: 승인 요청 표시 데이터 생성
  - `format_timeline`: 타임라인 포맷팅
  - `group_by_status`: 상태별 그룹핑
- **특징**:
  - 다양한 뷰 지원
  - 캐싱 최적화
  - Polymorphic 지원

## 백그라운드 Job

### 텍스트 추출 Job

#### TextExtractionJob
- **큐**: default
- **역할**: 첨부파일에서 텍스트 추출
- **프로세스**:
  1. 파일 타입 확인 (PDF/이미지)
  2. 적절한 추출 방법 선택 (PDF 파서/OCR)
  3. 텍스트 추출 및 저장
  4. 다음 Job 트리거 (AttachmentSummaryJob)
- **재시도**: 3회, exponential backoff

### AI 요약 Job

#### AttachmentSummaryJob
- **큐**: ai_processing
- **역할**: AI를 통한 영수증 요약
- **프로세스**:
  1. 추출된 텍스트 로드
  2. Gemini API 호출
  3. 요약 결과 저장
  4. UI 업데이트 (Turbo Stream)
- **Rate Limiting**: 분당 60회
- **에러 처리**: 실패 시 사용자 알림

### 리포트 생성 Job

#### ReportExportJob
- **큐**: reports
- **역할**: 대량 리포트 생성
- **지원 형식**:
  - Excel (XLSX)
  - PDF
  - CSV
- **특징**:
  - 청크 단위 처리
  - 진행률 추적
  - 완료 알림
  - S3 업로드 지원

### 대시보드 업데이트 Job

#### DashboardUpdateJob
- **큐**: realtime
- **역할**: 실시간 대시보드 업데이트
- **트리거**:
  - 경비 제출
  - 승인/반려 처리
  - 월 마감
- **전송 방식**: Turbo Stream broadcast

### 새로운 백그라운드 Job

#### AttachmentAnalysisJob
- **큐**: ai_processing
- **역할**: 첨부파일 AI 분석
- **프로세스**:
  1. 첨부파일 텍스트 추출
  2. AI 분석 실행
  3. 결과 저장
  4. UI 업데이트
- **재시도**: 5회, exponential backoff

#### SheetTextExtractionJob
- **큐**: default
- **역할**: 경비 시트 첨부파일 텍스트 추출
- **프로세스**:
  1. PDF/이미지 파일 확인
  2. 텍스트 추출 (OCR/PDF Parser)
  3. 추출 결과 저장
  4. 분석 Job 트리거
- **특징**:
  - 대용량 파일 처리
  - 청크 단위 처리

#### SheetValidationJob
- **큐**: validation
- **역할**: 경비 시트 자동 검증
- **프로세스**:
  1. 검증 규칙 로드
  2. 단계별 검증 실행
  3. AI 검증 실행
  4. 결과 병합 및 저장
- **특징**:
  - 병렬 처리
  - 진행률 추적

#### ValidationJob
- **큐**: validation
- **역할**: 범용 검증 작업
- **프로세스**:
  1. 검증 대상 확인
  2. 적절한 검증 서비스 호출
  3. 결과 처리
  4. 알림 발송
- **특징**:
  - 플러그인 구조
  - 다양한 검증 유형 지원

#### ExtractTextFromAttachmentJob
- **큐**: default
- **역할**: 개별 첨부파일 텍스트 추출
- **프로세스**:
  1. 파일 타입 확인
  2. 적절한 추출 방법 선택
  3. 텍스트 추출
  4. 요약 Job 트리거
- **특징**:
  - 다양한 파일 형식 지원
  - 에러 복구

## 프론트엔드 구조

### Stimulus 컨트롤러

#### expense_item_form_controller.js
- **역할**: 경비 항목 폼 동적 제어
- **주요 기능**:
  - 경비 코드 선택 시 커스텀 필드 렌더링
  - 월 선택 시 자동 시트 생성
  - 실시간 금액 계산
  - 영수증 드래그앤드롭
  - 최근 제출 내용 자동 입력

#### expense_items_sorter_controller.js
- **역할**: 경비 항목 정렬
- **기능**:
  - SortableJS 통합
  - 드래그앤드롭 정렬
  - 일괄 정렬 (날짜/금액/코드순)
  - 서버 동기화
  - 모바일 지원

#### room_calendar_controller.js
- **역할**: 회의실 예약 캘린더 관리 (오버레이 렌더링 방식)
- **주요 기능**:
  - 예약 오버레이 렌더링 (absolute positioning)
  - 드래그 앤 드롭으로 예약 시간 변경
  - 리사이징으로 예약 시간 조정 (상단/하단 핸들)
  - 빈 셀 드래그로 새 예약 생성
  - 실시간 미리보기 표시
  - Optimistic UI: 드롭/리사이징 후 미리보기 유지
  - 에러 시 Turbo.visit으로 상태 복원
  - 모달 포커스 차별화 (일반 생성 vs 드래그 생성)
  - Turbo Frame/Stream 통합

#### approval_line_selector_controller.js
- **역할**: 결재선 선택 UI
- **기능**:
  - 칩 형태 UI
  - 자동완성 검색
  - 미리보기
  - 검증 피드백
  - 필수 승인자 표시

#### attachment_uploader_controller.js
- **역할**: 파일 업로드 관리
- **기능**:
  - 드래그앤드롭
  - 다중 파일 업로드
  - 진행률 표시
  - 미리보기 모달
  - 파일 크기 검증

#### ai_validation_controller.js
- **역할**: AI 검증 프로세스 제어
- **기능**:
  - 4단계 순차 검증 실행
  - 실시간 진행 상황 표시
  - 단계별 결과 로깅
  - 토큰 사용량 추적
  - 에러 처리 및 복구
  - WebSocket 실시간 업데이트

#### sortable_controller.js
- **역할**: 범용 정렬 기능
- **사용처**:
  - 결재선 단계 정렬
  - 승인자 그룹 멤버 정렬
  - 경비 코드 순서 정렬

#### client_validation_controller.js
- **역할**: 경비 항목 폼 클라이언트 사이드 검증
- **주요 기능**:
  - 실시간 필드 검증 (필수 필드, 금액 한도 등)
  - 제출된 시트 날짜 검증
  - 폼 로드 시 기본값 자동 검증
  - 오류 개수 표시 및 버튼 상태 관리
  - 툴팁을 통한 상세 에러 메시지 제공
  - 커스텀 필드 동적 검증

#### request_form_validation_controller.js
- **역할**: 신청서 폼 검증 제어
- **주요 기능**:
  - 동적 필드 실시간 검증
  - 필수 필드 확인
  - 결재선 필수 여부 검증
  - 제출 전 최종 검증
  - 오류 메시지 표시

### 새로운 Stimulus 컨트롤러

#### organization_selector_controller.js
- **역할**: 조직 트리 선택 UI
- **주요 기능**:
  - 조직 트리 펼치기/접기
  - 1차 하위 조직 자동 표시
  - 하위 조직 포함/제외 토글
  - 선택된 조직 하이라이트
  - Turbo Frame 네비게이션

#### closing_dashboard_controller.js
- **역할**: 경비 마감 대시보드 제어
- **주요 기능**:
  - 실시간 통계 업데이트
  - 일괄 처리 제어
  - 알림 발송 관리
  - 엑셀 내보내기
  - 필터링 및 정렬

#### expense_sheet_approval_controller.js
- **역할**: 경비 시트 승인 UI
- **주요 기능**:
  - 승인 규칙 실시간 검증
  - 필수 승인자 표시
  - 승인 프로세스 시각화
  - 타임라인 애니메이션
  - 승인/반려 모달

#### sheet_attachment_uploader_controller.js
- **역할**: 시트 첨부파일 업로드
- **주요 기능**:
  - 법인카드 명세서 업로드
  - 다중 파일 처리
  - 실시간 분석 상태 표시
  - 거래 내역 매칭 UI
  - 드래그앤드롭 지원

#### expense_sheet_submission_controller.js
- **역할**: 경비 시트 제출 프로세스
- **주요 기능**:
  - 4단계 검증 UI
  - 제출 전 체크리스트
  - 검증 결과 표시
  - 승인선 미리보기
  - 제출 확인 다이얼로그

#### approval_timeline_controller.js
- **역할**: 승인 타임라인 시각화
- **주요 기능**:
  - 승인 단계 애니메이션
  - 실시간 상태 업데이트
  - 승인자 정보 툴팁
  - 진행률 표시
  - 이력 확장/축소

#### budget_mode_controller.js
- **역할**: 예산/실제 모드 전환
- **주요 기능**:
  - 모드 토글
  - 금액 필드 동적 표시/숨김
  - 자동 계산
  - 검증 규칙 전환

#### multiselect_controller.js
- **역할**: 다중 선택 UI
- **주요 기능**:
  - 체크박스 다중 선택
  - 전체 선택/해제
  - 선택 개수 표시
  - 일괄 작업 활성화

#### nested_fields_controller.js
- **역할**: 중첩 필드 관리
- **주요 기능**:
  - 동적 필드 추가/제거
  - 필드 순서 변경
  - 검증 규칙 적용
  - 템플릿 기반 렌더링

#### progress_animation_controller.js
- **역할**: 진행 상황 애니메이션
- **주요 기능**:
  - 진행률 바 애니메이션
  - 단계별 체크포인트
  - 완료 효과
  - 에러 상태 표시

### Turbo 사용 패턴

#### Turbo Frames
- `expense_items_list`: 경비 항목 목록
- `approval_details`: 승인 상세 정보
- `pdf_analysis_results`: PDF 분석 결과
- `flash_messages`: 플래시 메시지
- `expense_sheet_form`: 경비 시트 폼
- `modal`: 모달 팝업
- `request_form_fields`: 신청서 동적 필드
- `request_category_templates`: 카테고리별 템플릿 목록
- `approval_type_badge`: 승인 타입 배지

#### Turbo Streams
- 승인/반려 실시간 업데이트
- 경비 항목 추가/삭제
- 대시보드 통계 갱신
- 알림 표시
- PDF 분석 결과 업데이트

### UI 컴포넌트 (Tremor)

#### 메트릭 카드
- `tremor-metric-card`: 대시보드 통계
- `tremor-metric-value`: 금액 표시
- `tremor-metric-delta`: 변화량 표시
- `tremor-metric-label`: 레이블

#### 배지 및 상태
- `tremor-badge`: 상태 표시
- `tremor-badge-success`/`error`/`warning`: 색상 변형
- 진행률 바: 승인 진행 상황

#### 테이블
- `tremor-table`: 반응형 테이블
- 정렬 가능 헤더
- 페이지네이션
- 모바일 카드 뷰

#### 버튼
- `tremor-button-primary`: 주요 액션
- `tremor-button-secondary`: 보조 액션
- `tremor-button-danger`: 위험 액션

## 데이터베이스 구조

### 주요 테이블 관계

#### 경비 관련
- users → expense_sheets (1:N)
- expense_sheets → expense_items (1:N)
- expense_items → expense_code (N:1)
- expense_items → expense_attachments (1:N)
- expense_sheets → expense_sheet_attachments (1:N)
- expense_sheets → pdf_analysis_results (1:N)
- expense_sheets → expense_validation_histories (1:N)
- pdf_analysis_results → transaction_matches (1:N)
- transaction_matches → expense_items (N:1)

#### 결재 관련 (Polymorphic)
- expense_items → approval_requests (1:N, as: :approvable)
- request_forms → approval_requests (1:N, as: :approvable)
- approval_requests → approval_line (N:1)
- approval_requests → approval_histories (1:N)
- approval_line → approval_line_steps (1:N)
- approval_requests → approval_request_steps (1:N)

#### 승인자 그룹 및 규칙
- approver_groups → approver_group_members (1:N)
- expense_codes → expense_code_approval_rules (1:N)
- expense_code_approval_rules → approver_groups (N:1)
- expense_sheets → expense_sheet_approval_rules (N:1)
- expense_codes → attachment_requirements (1:1)
- attachment_requirements → attachment_analysis_rules (1:N)
- attachment_requirements → attachment_validation_rules (1:N)

#### 신청서 관련
- request_categories → request_templates (1:N)
- request_templates → request_template_fields (1:N)
- request_templates → request_template_approval_rules (1:N)
- request_templates → request_forms (1:N)
- request_template_approval_rules → approver_groups (N:1)
- request_forms → request_form_attachments (1:N)
- request_forms → users (N:1)

#### 조직 관련
- organizations → users (1:N)
- organizations → cost_centers (1:N)
- organizations → approver_groups (1:N)
- organizations → request_categories (1:N)
- organizations → expense_closing_statuses (1:N)
- organizations (자기 참조) → parent/children

#### 회의실 예약
- room_categories → rooms (1:N)
- rooms → room_reservations (1:N)
- room_reservations → users (N:1)
- room_reservations → organizations (N:1)

### 주요 인덱스

#### 경비 관련
- expense_items: `[expense_sheet_id, position]` - 정렬 최적화
- expense_items: `[expense_date]` - 날짜 검색
- expense_items: `[expense_code_id]` - 코드별 집계
- expense_sheets: `[user_id, year, month]` (unique) - 중복 방지
- expense_sheets: `[organization_id, status]` - 조직별 조회
- expense_sheets: `[status, year, month]` - 마감 처리
- expense_validation_histories: `[expense_sheet_id, created_at]` - 이력 조회

#### 결재 관련
- approval_requests: `[approvable_type, approvable_id]` (polymorphic) - 승인 대상 조회
- approval_requests: `[status, current_step]` - 승인 대기 목록
- approval_histories: `[approval_request_id, step_order]` - 승인 이력
- approval_line_steps: `[approval_line_id, step_order]` - 결재선 단계

#### 사용자 및 조직
- users: `[email]` (unique) - 로그인
- users: `[organization_id, is_active]` - 조직별 사용자
- organizations: `[parent_organization_id]` - 조직 트리
- organizations: `[talenx_organization_id]` (unique) - 외부 시스템 매핑

#### 신청서 관련
- request_forms: `[user_id, status]` - 사용자별 신청서
- request_forms: `[request_template_id, created_at]` - 템플릿별 통계
- request_templates: `[request_category_id, display_order]` - 카테고리별 표시

#### 기타
- expense_codes: `[display_order]` - UI 표시 순서
- room_reservations: `[room_id, date, start_time]` - 예약 충돌 검사
- room_reservations: `[user_id, date]` - 사용자별 예약

### JSONB 필드

#### 경비 관련
- expense_items.`custom_fields`: 동적 필드 저장
- expense_codes.`validation_rules`: 검증 규칙 정의
- expense_codes.`required_fields`: 필수 필드 정의
- expense_attachments.`ai_summary`: AI 분석 요약
  ```json
  {
    "category": "식사/음식",
    "summary": "요약 내용",
    "key_info": {
      "store_name": "가게명",
      "amount": 50000,
      "date": "2025-01-15"
    }
  }
  ```

#### AI 분석 관련
- pdf_analysis_results.`analysis_data`: PDF 분석 결과
  ```json
  {
    "card_type": "신한카드",
    "transactions": [...],
    "total_amount": 1000000,
    "period": "2025-01"
  }
  ```
- transaction_matches.`transaction_data`: 거래 매칭 정보
- expense_validation_histories.`validation_details`: 검증 상세
- expense_validation_histories.`step_results`: 단계별 결과
  ```json
  {
    "step1": {"passed": true, "message": "..."},
    "step2": {"passed": false, "issues": [...]},
    "step3": {"passed": true, "metrics": {...}},
    "step4": {"passed": true, "score": 85}
  }
  ```

#### 신청서 관련
- request_forms.`form_data`: 동적 폼 데이터 저장
- request_template_fields.`options`: select 필드 옵션

#### 기타
- expense_sheet_attachments.`analysis_data`: 시트 첨부 분석
- expense_closing_statuses.`summary_data`: 마감 요약 데이터

## 주요 기능 흐름

### 경비 제출 프로세스

1. **경비 시트 생성**
   - 사용자가 월 선택
   - 시트 자동 생성 또는 기존 시트 로드
   - 상태: `draft`

2. **경비 항목 추가**
   - 경비 코드 선택
   - 커스텀 필드 동적 로드
   - 영수증 첨부 (선택)
   - 결재선 선택 (필요시)
   - 임시 저장 가능

3. **검증 프로세스**
   - 필수 필드 확인
   - 금액 한도 검증
   - 승인자 그룹 요구사항 확인
   - 결재선 유효성 검증

4. **제출**
   - 모든 항목 최종 검증
   - 시트 상태: `submitted`
   - 승인 요청 생성
   - 첫 승인자에게 알림

### 결재 승인 프로세스

1. **승인 대기**
   - 승인자 대시보드에 표시
   - 현재 단계 승인자만 처리 가능
   - 병렬/순차 처리 지원

2. **승인/반려 처리**
   - 상세 정보 검토
   - 첨부 파일 확인
   - 코멘트 작성
   - 승인 또는 반려 결정

3. **다음 단계 진행**
   - 승인 시: 다음 단계로
   - 반려 시: 프로세스 종료
   - 모든 단계 완료 시: 시트 `approved`

4. **완료 처리**
   - 시트 상태 업데이트
   - 이력 저장
   - 관련자 알림

### AI 영수증 분석 프로세스

1. **파일 업로드**
   - PDF/이미지 파일 업로드
   - Active Storage 저장
   - TextExtractionJob 큐잉

2. **텍스트 추출**
   - PDF: 직접 텍스트 추출
   - 이미지: OCR 처리
   - 추출 결과 저장

3. **AI 분석**
   - AttachmentSummaryJob 실행
   - Gemini API 호출
   - 영수증 분류
   - 카테고리별 요약 생성

4. **결과 표시**
   - Turbo Stream으로 UI 업데이트
   - 요약 정보 표시
   - 경비 항목 자동 채우기 (선택)

### 신청서 작성 및 제출 프로세스

1. **카테고리 선택**
   - 사용자가 신청서 카테고리 선택
   - 활성화된 카테고리만 표시
   - 카테고리별 설명 제공

2. **템플릿 선택**
   - 선택한 카테고리의 템플릿 목록 표시
   - 템플릿별 필수 승인자 그룹 표시
   - 템플릿 설명 및 필요 정보 안내

3. **신청서 작성**
   - 템플릿 기반 동적 폼 생성
   - 필드 타입별 적절한 입력 컨트롤 렌더링
   - 필수 필드 검증
   - 파일 첨부 (선택)
   - 임시 저장 지원

4. **결재선 설정**
   - 템플릿 승인 규칙 기반 자동 설정
   - 보직자/조직리더 자동 포함
   - 추가 결재선 선택 가능

5. **제출 및 승인 요청**
   - 최종 검증
   - 신청서 상태: `submitted`
   - Polymorphic 승인 요청 생성
   - 첫 승인자에게 알림

### 통합 승인 프로세스

1. **승인 대시보드**
   - 경비와 신청서 통합 표시
   - 타입별 배지로 구분 (경비: 파란색, 신청서: 보라색)
   - Polymorphic 쿼리로 통합 조회

2. **승인/반려 처리**
   - approvable_type에 따른 분기 처리
   - 경비: ExpenseItem 상태 업데이트
   - 신청서: RequestForm 상태 업데이트
   - 공통 승인 이력 기록

### 월 마감 프로세스

1. **마감 준비**
   - 미제출 시트 확인
   - 승인 대기 항목 확인
   - 관리자 검토

2. **마감 실행**
   - MonthlyClosingJob 실행
   - 시트 상태: `closed`
   - 수정 불가 처리

3. **다음 월 준비**
   - 새 월 시트 자동 생성
   - 반복 항목 복사 (선택)
   - 사용자 알림

## 보안 및 권한

### 인증 (Authentication)
- 세션 기반 인증
- BCrypt 패스워드 해싱
- Remember me 기능

### 권한 (Authorization)
- 역할 기반 접근 제어
- 관리자/일반 사용자 구분
- 승인자 권한 체크

### 데이터 보안
- Strong Parameters 사용
- CSRF 보호
- XSS 방지
- SQL Injection 방지

## 성능 최적화

### 데이터베이스
- N+1 쿼리 방지 (includes 사용)
- 적절한 인덱싱
- WAL 모드 사용 (SQLite)

### 캐싱
- Fragment 캐싱
- Russian Doll 캐싱
- Turbo 캐시 제어

### 백그라운드 처리
- Solid Queue 사용
- 우선순위별 큐 분리
- 재시도 로직

## 테스팅

### 단위 테스트
- 모델 테스트
- 서비스 테스트
- Job 테스트

### 통합 테스트
- 컨트롤러 테스트
- 시스템 테스트
- API 테스트

### 테스트 커버리지
- 목표: 80% 이상
- 핵심 비즈니스 로직: 90% 이상

---

*문서 버전: 1.2.0*
*최종 업데이트: 2025-09-09*