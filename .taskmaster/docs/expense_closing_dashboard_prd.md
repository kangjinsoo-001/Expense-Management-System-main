# 경비 마감 대시보드 리팩토링 PRD
Product Requirements Document

## 1. 개요

### 1.1 목적
현재 관리자 전용으로 제공되는 경비 마감 대시보드를 전면 재설계하여, 조직 관리자들이 소속 직원들의 경비 제출 현황을 효과적으로 모니터링하고 관리할 수 있는 시스템으로 개선

### 1.2 현재 문제점
- 단순한 리스트 형태로 전체 경비 시트만 표시
- 조직별 필터링 기능 부재
- 개인별 제출 현황 파악 불가
- 일괄 마감 처리 기능 없음
- 관리자만 접근 가능 (조직장/보직자 접근 불가)

### 1.3 목표
- 조직 계층 구조 기반 브라우징
- 구성원별 경비 제출/승인 상태 실시간 모니터링
- 승인 완료된 경비의 일괄 마감 처리
- 조직 관리자 권한 확대

## 2. 사용자 스토리

### 2.1 조직 관리자 (팀장/부서장)
- **AS-IS**: 팀원들의 경비 제출 현황을 개별적으로 확인해야 함
- **TO-BE**: 대시보드에서 팀 전체의 제출 현황을 한눈에 파악하고 미제출자에게 알림 발송

### 2.2 재무팀 담당자
- **AS-IS**: 전체 경비 시트를 일일이 확인하며 마감 처리
- **TO-BE**: 조직별로 승인 완료된 경비를 일괄 선택하여 마감 처리

### 2.3 경영진
- **AS-IS**: 월별 경비 마감 현황을 별도 보고받음
- **TO-BE**: 대시보드에서 실시간으로 조직별 마감 진행률 확인

## 3. 기능 요구사항

### 3.1 조직 브라우저 (기존 컴포넌트 재사용)
- `organization_expenses` 페이지의 조직 트리 구조 재사용
- 좌측 사이드바에 계층적 조직 트리 표시
- 펼치기/접기 기능
- 선택한 조직의 하위 조직 포함 여부 토글

### 3.2 기간 네비게이션 (기존 컴포넌트 재사용)
- `organization_expenses` 페이지의 월/년도 네비게이션 재사용
- 이전/다음 월 이동 버튼
- 월별/연도별 보기 모드 전환
- 현재 선택된 기간 표시

### 3.3 구성원 제출 현황 테이블
#### 표시 정보
- 사원 정보 (이름, 사번, 직급, 부서)
- 경비 시트 상태
  - 미작성 (경비 시트 없음)
  - 작성중 (draft 상태)
  - 제출됨 (submitted 상태)
  - 승인중 (approval_in_progress)
  - 승인완료 (approved)
  - 마감완료 (closed)
- 제출 일시
- 승인 일시
- 총 금액
- 경비 항목 수

#### 필터링 옵션
- 상태별 필터 (체크박스)
- 이름/사번 검색
- 금액 범위 필터

### 3.4 일괄 처리 기능
- 승인 완료된 경비 일괄 선택
- 선택된 항목 일괄 마감 처리
- 마감 처리 시 검증
  - 모든 항목이 승인 완료 상태인지 확인
  - 필수 첨부파일 확인
- 처리 결과 요약 표시

### 3.5 통계 및 요약
- 선택 조직의 제출률 (제출/전체)
- 승인률 (승인완료/제출)
- 마감률 (마감완료/승인완료)
- 총 경비 금액
- 평균 처리 시간

### 3.6 알림 기능
- 미제출자 일괄 알림 발송
- 승인 대기중 알림
- 마감 임박 알림

## 4. 비기능 요구사항

### 4.1 성능
- 1000명 이상 조직 데이터 3초 이내 로딩
- 실시간 상태 업데이트 (Turbo Streams)
- 페이지네이션으로 대량 데이터 처리

### 4.2 권한 관리
- 시스템 관리자: 전체 조직 접근
- 조직 관리자: 자신이 관리하는 조직만 접근
- 일반 사용자: 접근 불가

### 4.3 사용성
- 반응형 디자인
- 키보드 단축키 지원
- 드래그 앤 드롭으로 일괄 선택
- 엑셀 내보내기

## 5. 기술 사양

### 5.1 아키텍처
```
Frontend:
- Stimulus Controllers
  - closing_dashboard_controller.js (메인 컨트롤러)
  - organization_selector_controller.js (조직 선택 - 재사용)
  - month_navigator_controller.js (기간 선택 - 재사용)
  
Backend:
- ClosingDashboardController (새로 생성)
  - index: 대시보드 메인
  - organization_members: 조직 구성원 목록 (AJAX)
  - batch_close: 일괄 마감 처리
  - send_notifications: 알림 발송
  
Models:
- ExpenseClosingStatus (새 모델)
  - user_id
  - organization_id
  - year
  - month
  - status
  - closed_at
  - closed_by_id
```

### 5.2 데이터 모델
```ruby
# 새로운 모델
class ExpenseClosingStatus < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :closed_by, class_name: 'User', optional: true
  
  enum status: {
    not_submitted: 0,
    draft: 1,
    submitted: 2,
    approval_in_progress: 3,
    approved: 4,
    closed: 5
  }
  
  scope :for_month, ->(year, month) { where(year: year, month: month) }
  scope :for_organization, ->(org) { where(organization: org) }
end

# 기존 모델 확장
class User
  has_many :expense_closing_statuses
  
  def expense_status_for_month(year, month)
    expense_closing_statuses.for_month(year, month).first
  end
end

class Organization
  def member_expense_statuses(year, month)
    users.includes(:expense_closing_statuses)
         .map { |u| u.expense_status_for_month(year, month) }
  end
end
```

### 5.3 API 엔드포인트
```ruby
# routes.rb
namespace :closing do
  resources :dashboard, only: [:index] do
    collection do
      get :organization_members
      post :batch_close
      post :send_notifications
      get :export
    end
  end
end
```

### 5.4 뷰 구조
```erb
<!-- app/views/closing/dashboard/index.html.erb -->
<div data-controller="closing-dashboard">
  <!-- 헤더: 기간 네비게이션 (재사용) -->
  <%= render 'shared/month_navigator', 
             year: @year, 
             month: @month %>
  
  <div class="flex">
    <!-- 좌측: 조직 브라우저 (재사용) -->
    <div class="w-96">
      <%= render 'shared/organization_browser',
                 organizations: @organizations,
                 selected: @selected_organization %>
    </div>
    
    <!-- 우측: 구성원 현황 -->
    <div class="flex-1">
      <%= turbo_frame_tag "member_statuses" do %>
        <%= render 'member_status_table',
                   members: @members,
                   statuses: @statuses %>
      <% end %>
    </div>
  </div>
</div>
```

## 6. 구현 단계

### Phase 1: 기반 구조 (1주)
1. ExpenseClosingStatus 모델 생성
2. ClosingDashboardController 생성
3. 기본 라우팅 설정
4. 권한 체크 로직 구현

### Phase 2: UI 컴포넌트 (1주)
1. 조직 브라우저 컴포넌트 추출 및 재사용
2. 월 네비게이션 컴포넌트 추출 및 재사용
3. 구성원 상태 테이블 구현
4. Stimulus 컨트롤러 작성

### Phase 3: 핵심 기능 (2주)
1. 조직별 구성원 조회 API
2. 경비 상태 실시간 동기화
3. 일괄 마감 처리 기능
4. 상태별 필터링

### Phase 4: 고급 기능 (1주)
1. 알림 발송 기능
2. 통계 대시보드
3. 엑셀 내보내기
4. 성능 최적화

### Phase 5: 테스트 및 배포 (1주)
1. 단위 테스트 작성
2. 통합 테스트
3. 사용자 권한 테스트
4. 성능 테스트
5. 배포 및 모니터링

## 7. 성공 지표

### 7.1 정량적 지표
- 월 마감 처리 시간 50% 단축
- 미제출자 수 30% 감소
- 마감 지연 건수 70% 감소

### 7.2 정성적 지표
- 조직 관리자 만족도 향상
- 재무팀 업무 효율성 증대
- 경비 처리 투명성 제고

## 8. 리스크 및 대응 방안

### 8.1 기술적 리스크
- **대량 데이터 처리**: 페이지네이션 및 캐싱 전략 수립
- **실시간 동기화**: Turbo Streams 활용 및 폴링 백업
- **권한 복잡도**: 철저한 권한 테스트 및 로깅

### 8.2 운영 리스크
- **사용자 교육**: 단계적 롤아웃 및 교육 자료 제공
- **데이터 정합성**: 마감 처리 전 검증 단계 강화
- **시스템 부하**: 점진적 기능 활성화

## 9. 향후 확장 계획

### 9.1 단기 (3개월)
- 모바일 앱 지원
- Slack/Teams 연동 알림
- 자동 마감 규칙 설정

### 9.2 장기 (6개월)
- AI 기반 이상 거래 탐지
- 예산 대비 실적 분석
- 타 시스템 연동 (ERP, 회계 시스템)

## 10. 참고 사항

### 10.1 기존 시스템 재사용 컴포넌트
- `app/views/organization_expenses/_organization_tree_node.html.erb`
- `app/javascript/controllers/organization_chart_controller.js`
- `app/controllers/organization_expenses_controller.rb` (조직 조회 로직)

### 10.2 관련 문서
- 기존 경비 통계 페이지 분석 문서
- 조직 구조 데이터 모델 문서
- 경비 승인 프로세스 문서

---

*작성일: 2025-01-07*
*작성자: Claude Code*
*버전: 1.0*