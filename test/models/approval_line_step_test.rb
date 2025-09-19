require "test_helper"

class ApprovalLineStepTest < ActiveSupport::TestCase
  setup do
    @approval_line = approval_lines(:one)
    @approver = users(:two)
    @step = approval_line_steps(:one)
  end
  
  # 유효성 검증 테스트
  test "should be valid with all required attributes" do
    step = ApprovalLineStep.new(
      approval_line: @approval_line,
      approver: @approver,
      step_order: 1,
      role: 'approve'
    )
    assert step.valid?
  end
  
  test "should require approval_line" do
    @step.approval_line = nil
    assert_not @step.valid?
    assert_includes @step.errors[:approval_line], "must exist"
  end
  
  test "should require approver" do
    @step.approver = nil
    assert_not @step.valid?
    assert_includes @step.errors[:approver], "must exist"
  end
  
  test "should require step_order" do
    @step.step_order = nil
    assert_not @step.valid?
    assert_includes @step.errors[:step_order], "can't be blank"
  end
  
  test "step_order should be positive" do
    @step.step_order = 0
    assert_not @step.valid?
    
    @step.step_order = -1
    assert_not @step.valid?
    
    @step.step_order = 1
    assert @step.valid?
  end
  
  test "should require role" do
    @step.role = nil
    assert_not @step.valid?
    assert_includes @step.errors[:role], "can't be blank"
  end
  
  test "should have unique step_order per approval_line" do
    duplicate_step = @approval_line.approval_line_steps.build(
      approver: users(:three),
      step_order: @step.step_order,
      role: 'approve'
    )
    assert_not duplicate_step.valid?
    assert_includes duplicate_step.errors[:step_order], "has already been taken"
  end
  
  test "different approval lines can have same step_order" do
    other_line = approval_lines(:two)
    other_step = other_line.approval_line_steps.build(
      approver: @approver,
      step_order: @step.step_order,
      role: 'approve'
    )
    assert other_step.valid?
  end
  
  test "approval_type should be valid when present" do
    @step.approval_type = 'invalid_type'
    assert_not @step.valid?
    
    @step.approval_type = 'all_required'
    assert @step.valid?
    
    @step.approval_type = 'single_allowed'
    assert @step.valid?
  end
  
  # Enum 테스트
  test "role enum should work correctly" do
    @step.role = 'approve'
    assert @step.role_approve?
    assert_not @step.role_reference?
    
    @step.role = 'reference'
    assert @step.role_reference?
    assert_not @step.role_approve?
  end
  
  test "approval_type enum should work correctly" do
    @step.approval_type = 'all_required'
    assert @step.approval_type_all_required?
    
    @step.approval_type = 'single_allowed'
    assert @step.approval_type_single_allowed?
  end
  
  # 스코프 테스트
  test "ordered scope should order by step_order" do
    steps = ApprovalLineStep.ordered
    previous_order = 0
    
    steps.each do |step|
      assert step.step_order > previous_order
      previous_order = step.step_order
    end
  end
  
  test "approvers scope should return only approve role" do
    approvers = ApprovalLineStep.approvers
    assert approvers.all? { |s| s.role_approve? }
  end
  
  test "referrers scope should return only reference role" do
    # 참조자 step 생성
    @approval_line.approval_line_steps.create!(
      approver: users(:three),
      step_order: 99,
      role: 'reference'
    )
    
    referrers = ApprovalLineStep.referrers
    assert referrers.all? { |s| s.role_reference? }
  end
  
  test "for_step scope should return steps for specific order" do
    steps = ApprovalLineStep.for_step(@step.step_order)
    assert steps.all? { |s| s.step_order == @step.step_order }
  end
  
  # 인스턴스 메서드 테스트
  test "is_approver? should check if role is approve" do
    @step.role = 'approve'
    assert @step.is_approver?
    
    @step.role = 'reference'
    assert_not @step.is_approver?
  end
  
  test "is_referrer? should check if role is reference" do
    @step.role = 'reference'
    assert @step.is_referrer?
    
    @step.role = 'approve'
    assert_not @step.is_referrer?
  end
  
  test "approval_type_display should return Korean text" do
    @step.approval_type = 'all_required'
    assert_equal '전체 승인 필요', @step.approval_type_display
    
    @step.approval_type = 'single_allowed'
    assert_equal '단일 승인 가능', @step.approval_type_display
    
    @step.approval_type = nil
    assert_nil @step.approval_type_display
  end
  
  test "role_display should return Korean text" do
    @step.role = 'approve'
    assert_equal '승인', @step.role_display
    
    @step.role = 'reference'
    assert_equal '참조', @step.role_display
  end
  
  # 관계 테스트
  test "should belong to approval_line" do
    assert_respond_to @step, :approval_line
    assert_instance_of ApprovalLine, @step.approval_line
  end
  
  test "should belong to approver" do
    assert_respond_to @step, :approver
    assert_instance_of User, @step.approver
  end
  
  # 다중 승인자 테스트
  test "multiple approvers can exist for same step" do
    # 같은 단계에 여러 승인자 추가
    step2 = @approval_line.approval_line_steps.create!(
      approver: users(:three),
      step_order: @step.step_order,
      role: 'approve',
      approval_type: 'all_required'
    )
    
    assert step2.valid?
    assert_equal @step.step_order, step2.step_order
  end
end