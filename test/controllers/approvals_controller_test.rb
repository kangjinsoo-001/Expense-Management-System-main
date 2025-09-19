require "test_helper"

class ApprovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @approver = users(:two)
    @non_approver = users(:one)
    @expense_item = expense_items(:with_approval)
    @approval_request = approval_requests(:pending)
    sign_in @approver
  end
  
  # Index 테스트
  test "should get index" do
    get approvals_url
    assert_response :success
    assert_select "h1", "승인 대기 목록"
  end
  
  test "index should show only items for current approver" do
    get approvals_url
    
    # 현재 승인자가 처리해야 할 항목만 표시
    assert_match @expense_item.expense_sheet.title, response.body
    
    # 다른 승인자의 항목은 표시되지 않아야 함
    other_request = approval_requests(:for_other_approver)
    assert_no_match other_request.expense_item.expense_sheet.title, response.body
  end
  
  test "index should filter by role" do
    # 승인 역할 필터
    get approvals_url, params: { role: "approve" }
    assert_response :success
    
    # 참조 역할 필터
    get approvals_url, params: { role: "reference" }
    assert_response :success
  end
  
  test "index should show pending count" do
    get approvals_url
    
    pending_count = ApprovalRequest.for_approver(@approver).in_progress.count
    assert_select ".pending-count", pending_count.to_s
  end
  
  # Show 테스트
  test "should show approval detail" do
    get approval_url(@approval_request)
    assert_response :success
    
    assert_match @expense_item.expense_sheet.title, response.body
    assert_match @expense_item.description, response.body
    assert_select "button", "승인"
    assert_select "button", "반려"
  end
  
  test "should not show approval for non-approver" do
    sign_in @non_approver
    
    get approval_url(@approval_request)
    assert_response :forbidden
  end
  
  test "referrer should only see view button" do
    # 참조자로 설정
    referrer = users(:three)
    @approval_request.approval_line.approval_line_steps.create!(
      approver: referrer,
      step_order: @approval_request.current_step,
      role: "reference"
    )
    
    sign_in referrer
    get approval_url(@approval_request)
    assert_response :success
    
    # 참조자는 승인/반려 버튼이 없고 열람만 가능
    assert_no_match "승인", response.body
    assert_no_match "반려", response.body
    assert_match "열람", response.body
  end
  
  # Approve 테스트
  test "should approve request" do
    assert_difference("ApprovalHistory.count", 1) do
      post approve_approval_url(@approval_request), params: {
        comment: "승인합니다"
      }
    end
    
    assert_redirected_to approvals_url
    follow_redirect!
    assert_match "승인 처리되었습니다", response.body
    
    history = ApprovalHistory.last
    assert_equal "approve", history.action
    assert_equal "승인합니다", history.comment
    assert_equal @approver, history.approver
  end
  
  test "should move to next step after approval" do
    # 다음 단계가 있는 경우
    @approval_request.approval_line.approval_line_steps.create!(
      approver: users(:three),
      step_order: 2,
      role: "approve"
    )
    
    current_step = @approval_request.current_step
    
    post approve_approval_url(@approval_request), params: {
      comment: "1단계 승인"
    }
    
    @approval_request.reload
    assert_equal current_step + 1, @approval_request.current_step
    assert @approval_request.status_pending?
  end
  
  test "should complete approval when last step" do
    # 마지막 단계인 경우
    @approval_request.update!(current_step: @approval_request.max_step)
    
    post approve_approval_url(@approval_request), params: {
      comment: "최종 승인"
    }
    
    @approval_request.reload
    assert @approval_request.status_approved?
  end
  
  test "should handle multiple approvers with all_required" do
    # 같은 단계에 여러 승인자 추가
    step = @approval_request.current_step_approvers.first
    step.update!(approval_type: "all_required")
    
    @approval_request.approval_line.approval_line_steps.create!(
      approver: users(:three),
      step_order: @approval_request.current_step,
      role: "approve",
      approval_type: "all_required"
    )
    
    # 첫 번째 승인
    post approve_approval_url(@approval_request)
    
    @approval_request.reload
    assert @approval_request.status_pending?
    assert_equal step.step_order, @approval_request.current_step # 같은 단계 유지
    
    # 두 번째 승인자로 로그인
    sign_in users(:three)
    post approve_approval_url(@approval_request)
    
    @approval_request.reload
    # 모든 승인자가 승인했으므로 다음 단계로
    assert_not_equal step.step_order, @approval_request.current_step
  end
  
  test "should handle single_allowed approval type" do
    # 같은 단계에 여러 승인자 추가 (단일 승인 가능)
    step = @approval_request.current_step_approvers.first
    step.update!(approval_type: "single_allowed")
    
    @approval_request.approval_line.approval_line_steps.create!(
      approver: users(:three),
      step_order: @approval_request.current_step,
      role: "approve",
      approval_type: "single_allowed"
    )
    
    # 한 명이 승인하면 바로 다음 단계로
    post approve_approval_url(@approval_request)
    
    @approval_request.reload
    assert_not_equal step.step_order, @approval_request.current_step
  end
  
  test "should not approve if already processed" do
    # 이미 처리한 경우
    @approval_request.approval_histories.create!(
      approver: @approver,
      step_order: @approval_request.current_step,
      role: "approve",
      action: "approve",
      processed_at: Time.current
    )
    
    post approve_approval_url(@approval_request)
    
    assert_response :unprocessable_entity
    assert_match "이미 처리한 요청입니다", response.body
  end
  
  # Reject 테스트
  test "should reject request" do
    assert_difference("ApprovalHistory.count", 1) do
      post reject_approval_url(@approval_request), params: {
        comment: "서류 미비로 반려합니다"
      }
    end
    
    assert_redirected_to approvals_url
    follow_redirect!
    assert_match "반려 처리되었습니다", response.body
    
    @approval_request.reload
    assert @approval_request.status_rejected?
    
    history = ApprovalHistory.last
    assert_equal "reject", history.action
    assert_equal "서류 미비로 반려합니다", history.comment
  end
  
  test "should require comment for rejection" do
    post reject_approval_url(@approval_request), params: {
      comment: "" # 빈 코멘트
    }
    
    assert_response :unprocessable_entity
    assert_match "반려 사유를 입력해주세요", response.body
  end
  
  # View 테스트 (참조자)
  test "should record view for referrer" do
    # 참조자 설정
    referrer = users(:three)
    @approval_request.approval_line.approval_line_steps.create!(
      approver: referrer,
      step_order: @approval_request.current_step,
      role: "reference"
    )
    
    sign_in referrer
    
    assert_difference("ApprovalHistory.count", 1) do
      post view_approval_url(@approval_request)
    end
    
    history = ApprovalHistory.last
    assert_equal "view", history.action
    assert_equal referrer, history.approver
  end
  
  # Turbo Stream 응답 테스트
  test "should respond with turbo stream on approve" do
    post approve_approval_url(@approval_request), params: {
      comment: "승인"
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_match "turbo-stream", response.content_type
  end
  
  test "should respond with turbo stream on reject" do
    post reject_approval_url(@approval_request), params: {
      comment: "반려"
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_match "turbo-stream", response.content_type
  end
  
  # 권한 검증 테스트
  test "non-approver cannot approve" do
    sign_in @non_approver
    
    post approve_approval_url(@approval_request), params: {
      comment: "승인"
    }
    
    assert_response :forbidden
  end
  
  test "non-approver cannot reject" do
    sign_in @non_approver
    
    post reject_approval_url(@approval_request), params: {
      comment: "반려"
    }
    
    assert_response :forbidden
  end
  
  test "should redirect to login when not authenticated" do
    sign_out @approver
    
    get approvals_url
    assert_redirected_to new_user_session_url
    
    get approval_url(@approval_request)
    assert_redirected_to new_user_session_url
    
    post approve_approval_url(@approval_request)
    assert_redirected_to new_user_session_url
  end
  
  # 페이지네이션 테스트
  test "should paginate approval list" do
    # 많은 승인 요청 생성
    30.times do |i|
      expense_item = @approver.expense_items.create!(
        expense_sheet: expense_sheets(:one),
        date: Date.current,
        description: "테스트 항목 #{i}",
        amount: 10000
      )
      
      approval_line = @approver.approval_lines.create!(
        name: "테스트 결재선 #{i}",
        is_active: true
      )
      
      approval_line.approval_line_steps.create!(
        approver: @approver,
        step_order: 1,
        role: "approve"
      )
      
      expense_item.update!(approval_line: approval_line)
    end
    
    get approvals_url
    assert_response :success
    
    # 페이지네이션 컨트롤 확인
    assert_select ".pagination"
    
    # 두 번째 페이지
    get approvals_url, params: { page: 2 }
    assert_response :success
  end
  
  # 검색 및 필터 테스트
  test "should search approvals by expense sheet title" do
    get approvals_url, params: { q: @expense_item.expense_sheet.title }
    assert_response :success
    assert_match @expense_item.expense_sheet.title, response.body
  end
  
  test "should filter by date range" do
    get approvals_url, params: {
      start_date: 1.week.ago,
      end_date: Date.current
    }
    assert_response :success
  end
end