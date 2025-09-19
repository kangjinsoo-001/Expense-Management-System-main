require "test_helper"

class ApprovalLineTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @approval_line = approval_lines(:one)
  end
  
  # 유효성 검증 테스트
  test "should be valid with all required attributes" do
    approval_line = ApprovalLine.new(
      user: @user,
      name: "테스트 결재선",
      is_active: true
    )
    assert approval_line.valid?
  end
  
  test "should require name" do
    @approval_line.name = nil
    assert_not @approval_line.valid?
    assert_includes @approval_line.errors[:name], "can't be blank"
  end
  
  test "should require user" do
    @approval_line.user = nil
    assert_not @approval_line.valid?
    assert_includes @approval_line.errors[:user], "must exist"
  end
  
  test "should have unique name per user" do
    duplicate_line = @user.approval_lines.build(name: @approval_line.name)
    assert_not duplicate_line.valid?
    assert_includes duplicate_line.errors[:name], "has already been taken"
  end
  
  test "different users can have same approval line name" do
    other_user = users(:two)
    other_line = other_user.approval_lines.build(
      name: @approval_line.name,
      is_active: true
    )
    assert other_line.valid?
  end
  
  # 관계 테스트
  test "should have many approval line steps" do
    assert_respond_to @approval_line, :approval_line_steps
  end
  
  test "should have many approval requests" do
    assert_respond_to @approval_line, :approval_requests
  end
  
  test "should destroy associated steps when destroyed" do
    approval_line = approval_lines(:complete_line)
    assert_difference 'ApprovalLineStep.count', -approval_line.approval_line_steps.count do
      approval_line.destroy
    end
  end
  
  # 스코프 테스트
  test "active scope should return only active lines" do
    active_lines = ApprovalLine.active
    assert active_lines.all?(&:is_active)
  end
  
  test "inactive scope should return only inactive lines" do
    @approval_line.update(is_active: false)
    inactive_lines = ApprovalLine.inactive
    assert inactive_lines.all? { |line| !line.is_active }
  end
  
  test "with_steps scope should include approval line steps" do
    lines = ApprovalLine.with_steps
    assert lines.first.association(:approval_line_steps).loaded?
  end
  
  # 인스턴스 메서드 테스트
  test "active? should return is_active value" do
    @approval_line.is_active = true
    assert @approval_line.active?
    
    @approval_line.is_active = false
    assert_not @approval_line.active?
  end
  
  test "has_steps? should check if steps exist" do
    approval_line = approval_lines(:complete_line)
    assert approval_line.has_steps?
    
    approval_line.approval_line_steps.destroy_all
    assert_not approval_line.has_steps?
  end
  
  test "step_count should return number of steps" do
    approval_line = approval_lines(:complete_line)
    expected_count = approval_line.approval_line_steps.count
    assert_equal expected_count, approval_line.step_count
  end
  
  test "approvers should return list of approvers" do
    approval_line = approval_lines(:complete_line)
    approvers = approval_line.approvers
    
    assert_kind_of Array, approvers
    assert approvers.all? { |a| a.is_a?(User) }
  end
  
  test "approver_names should return comma-separated names" do
    approval_line = approval_lines(:complete_line)
    expected_names = approval_line.approval_line_steps
                                .ordered
                                .includes(:approver)
                                .map { |s| s.approver.name }
                                .join(', ')
    
    assert_equal expected_names, approval_line.approver_names
  end
  
  test "summary should return formatted summary" do
    approval_line = approval_lines(:complete_line)
    summary = approval_line.summary
    
    assert_includes summary, approval_line.name
    assert_includes summary, "#{approval_line.step_count}단계"
  end
  
  # 검증 관련 테스트
  test "should not allow deletion with associated approval requests" do
    approval_line = approval_lines(:with_requests)
    
    assert_not approval_line.destroy
    assert approval_line.errors[:base].any?
  end
  
  test "should allow deletion without approval requests" do
    approval_line = approval_lines(:complete_line)
    approval_line.approval_requests.destroy_all
    
    assert approval_line.destroy
  end
end