require "test_helper"

class ApprovalRequestTest < ActiveSupport::TestCase
  setup do
    @expense_item = expense_items(:with_approval)
    @approval_line = approval_lines(:complete_line)
    @approval_request = approval_requests(:pending)
    @user = users(:two)
  end
  
  # 유효성 검증 테스트
  test "should be valid with all required attributes" do
    request = ApprovalRequest.new(
      expense_item: @expense_item,
      approval_line: @approval_line,
      current_step: 1,
      status: 'pending'
    )
    assert request.valid?
  end
  
  test "should require expense_item" do
    @approval_request.expense_item = nil
    assert_not @approval_request.valid?
    assert_includes @approval_request.errors[:expense_item], "must exist"
  end
  
  test "should require approval_line" do
    @approval_request.approval_line = nil
    assert_not @approval_request.valid?
    assert_includes @approval_request.errors[:approval_line], "must exist"
  end
  
  test "should require current_step" do
    @approval_request.current_step = nil
    assert_not @approval_request.valid?
    assert_includes @approval_request.errors[:current_step], "can't be blank"
  end
  
  test "current_step should be positive" do
    @approval_request.current_step = 0
    assert_not @approval_request.valid?
    
    @approval_request.current_step = 1
    assert @approval_request.valid?
  end
  
  test "should require status" do
    @approval_request.status = nil
    assert_not @approval_request.valid?
    assert_includes @approval_request.errors[:status], "can't be blank"
  end
  
  test "expense_item_id should be unique" do
    duplicate_request = ApprovalRequest.new(
      expense_item: @approval_request.expense_item,
      approval_line: @approval_line,
      current_step: 1,
      status: 'pending'
    )
    assert_not duplicate_request.valid?
    assert_includes duplicate_request.errors[:expense_item_id], 
                   '하나의 경비 항목은 하나의 승인 요청만 가질 수 있습니다'
  end
  
  # Enum 테스트
  test "status enum should work correctly" do
    @approval_request.status = 'pending'
    assert @approval_request.status_pending?
    
    @approval_request.status = 'approved'
    assert @approval_request.status_approved?
    
    @approval_request.status = 'rejected'
    assert @approval_request.status_rejected?
    
    @approval_request.status = 'cancelled'
    assert @approval_request.status_cancelled?
  end
  
  # 스코프 테스트
  test "in_progress scope should return pending requests" do
    requests = ApprovalRequest.in_progress
    assert requests.all? { |r| r.status_pending? }
  end
  
  test "completed scope should return approved or rejected requests" do
    requests = ApprovalRequest.completed
    assert requests.all? { |r| r.status_approved? || r.status_rejected? }
  end
  
  test "for_approver scope should return requests for specific approver" do
    approver = @approval_request.approval_line.approval_line_steps
                               .where(step_order: @approval_request.current_step)
                               .first.approver
    
    requests = ApprovalRequest.for_approver(approver)
    assert requests.include?(@approval_request)
  end
  
  # 인스턴스 메서드 테스트
  test "current_step_approvers should return steps for current step" do
    approvers = @approval_request.current_step_approvers
    assert approvers.all? { |s| s.step_order == @approval_request.current_step }
  end
  
  test "current_step_approval_type should return approval type" do
    # 단일 승인자인 경우
    assert_nil @approval_request.current_step_approval_type
    
    # 여러 승인자 추가
    @approval_request.approval_line.approval_line_steps.create!(
      approver: users(:three),
      step_order: @approval_request.current_step,
      role: 'approve',
      approval_type: 'all_required'
    )
    
    assert_equal 'all_required', @approval_request.current_step_approval_type
  end
  
  test "can_proceed_to_next_step? should check approval status" do
    # 승인 없이는 다음 단계로 진행 불가
    assert_not @approval_request.can_proceed_to_next_step?
    
    # 승인 이력 추가
    @approval_request.approval_histories.create!(
      approver: @user,
      action: 'approve',
      step_order: @approval_request.current_step,
      processed_at: Time.current
    )
    
    assert @approval_request.can_proceed_to_next_step?
  end
  
  test "max_step should return maximum step order" do
    max_step = @approval_request.approval_line.approval_line_steps.maximum(:step_order)
    assert_equal max_step, @approval_request.max_step
  end
  
  test "completed? should check if approved or rejected" do
    @approval_request.status = 'pending'
    assert_not @approval_request.completed?
    
    @approval_request.status = 'approved'
    assert @approval_request.completed?
    
    @approval_request.status = 'rejected'
    assert @approval_request.completed?
  end
  
  test "progress_percentage should calculate progress" do
    @approval_request.current_step = 1
    @approval_request.status = 'pending'
    max_step = @approval_request.max_step
    expected = ((1 - 1) * 100.0 / max_step).round
    assert_equal expected, @approval_request.progress_percentage
    
    @approval_request.status = 'approved'
    assert_equal 100, @approval_request.progress_percentage
  end
  
  test "current_status_display should return Korean text" do
    @approval_request.status = 'pending'
    assert_includes @approval_request.current_status_display, '진행중'
    
    @approval_request.status = 'approved'
    assert_equal '승인 완료', @approval_request.current_status_display
    
    @approval_request.status = 'rejected'
    assert_equal '반려됨', @approval_request.current_status_display
  end
  
  test "pending_approvers should return current step approvers" do
    @approval_request.status = 'pending'
    approvers = @approval_request.pending_approvers
    
    assert approvers.all? { |a| a.is_a?(User) }
  end
  
  test "has_been_processed_by? should check approval history" do
    assert_not @approval_request.has_been_processed_by?(@user)
    
    @approval_request.approval_histories.create!(
      approver: @user,
      action: 'approve',
      step_order: @approval_request.current_step,
      processed_at: Time.current
    )
    
    assert @approval_request.has_been_processed_by?(@user)
  end
  
  test "can_be_approved_by? should check approval permission" do
    # 현재 단계의 승인자가 아닌 경우
    non_approver = users(:one)
    assert_not @approval_request.can_be_approved_by?(non_approver)
    
    # 현재 단계의 승인자인 경우
    current_approver = @approval_request.current_step_approvers.approvers.first.approver
    assert @approval_request.can_be_approved_by?(current_approver)
    
    # 이미 처리한 경우
    @approval_request.approval_histories.create!(
      approver: current_approver,
      action: 'approve',
      step_order: @approval_request.current_step,
      processed_at: Time.current
    )
    assert_not @approval_request.can_be_approved_by?(current_approver)
  end
  
  # 승인/반려 처리 테스트
  test "process_approval should create history and update status" do
    approver = @approval_request.current_step_approvers.approvers.first.approver
    
    assert_difference '@approval_request.approval_histories.count', 1 do
      result = @approval_request.process_approval(approver, "승인합니다")
      assert result
    end
    
    history = @approval_request.approval_histories.last
    assert_equal 'approve', history.action
    assert_equal "승인합니다", history.comment
  end
  
  test "process_approval should move to next step" do
    approver = @approval_request.current_step_approvers.approvers.first.approver
    current_step = @approval_request.current_step
    
    @approval_request.process_approval(approver)
    
    if @approval_request.current_step < @approval_request.max_step
      assert_equal current_step + 1, @approval_request.reload.current_step
    else
      assert @approval_request.reload.status_approved?
    end
  end
  
  test "process_rejection should create history and update status" do
    approver = @approval_request.current_step_approvers.approvers.first.approver
    
    assert_difference '@approval_request.approval_histories.count', 1 do
      result = @approval_request.process_rejection(approver, "반려합니다")
      assert result
    end
    
    assert @approval_request.reload.status_rejected?
    
    history = @approval_request.approval_histories.last
    assert_equal 'reject', history.action
    assert_equal "반려합니다", history.comment
  end
  
  test "process_rejection should require comment" do
    approver = @approval_request.current_step_approvers.approvers.first.approver
    
    assert_raises(ArgumentError) do
      @approval_request.process_rejection(approver, "")
    end
  end
  
  test "record_view should create view history for referrer" do
    # 참조자 step 추가
    referrer_step = @approval_request.approval_line.approval_line_steps.create!(
      approver: users(:three),
      step_order: @approval_request.current_step,
      role: 'reference'
    )
    
    referrer = referrer_step.approver
    
    assert_difference '@approval_request.approval_histories.count', 1 do
      @approval_request.record_view(referrer)
    end
    
    history = @approval_request.approval_histories.last
    assert_equal 'view', history.action
  end
end