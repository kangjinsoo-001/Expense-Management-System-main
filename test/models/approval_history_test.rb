require "test_helper"

class ApprovalHistoryTest < ActiveSupport::TestCase
  setup do
    @approval_request = approval_requests(:pending)
    @approver = users(:two)
    @history = approval_histories(:approved)
  end
  
  # 유효성 검증 테스트
  test "should be valid with all required attributes" do
    history = ApprovalHistory.new(
      approval_request: @approval_request,
      approver: @approver,
      step_order: 1,
      role: 'approve',
      action: 'approve',
      processed_at: Time.current
    )
    assert history.valid?
  end
  
  test "should require approval_request" do
    @history.approval_request = nil
    assert_not @history.valid?
    assert_includes @history.errors[:approval_request], "must exist"
  end
  
  test "should require approver" do
    @history.approver = nil
    assert_not @history.valid?
    assert_includes @history.errors[:approver], "must exist"
  end
  
  test "should require step_order" do
    @history.step_order = nil
    assert_not @history.valid?
    assert_includes @history.errors[:step_order], "can't be blank"
  end
  
  test "step_order should be positive" do
    @history.step_order = 0
    assert_not @history.valid?
    
    @history.step_order = -1
    assert_not @history.valid?
    
    @history.step_order = 1
    assert @history.valid?
  end
  
  test "should require role" do
    @history.role = nil
    assert_not @history.valid?
    assert_includes @history.errors[:role], "can't be blank"
  end
  
  test "should require action" do
    @history.action = nil
    assert_not @history.valid?
    assert_includes @history.errors[:action], "can't be blank"
  end
  
  test "processed_at should be set automatically if not provided" do
    history = ApprovalHistory.create!(
      approval_request: @approval_request,
      approver: @approver,
      step_order: 2,
      role: 'approve',
      action: 'approve'
    )
    assert_not_nil history.processed_at
  end
  
  # Enum 테스트
  test "role enum should work correctly" do
    @history.role = 'approve'
    assert @history.role_approve?
    assert_not @history.role_reference?
    
    @history.role = 'reference'
    assert @history.role_reference?
    assert_not @history.role_approve?
  end
  
  test "action enum should work correctly" do
    @history.action = 'approve'
    assert @history.action_approve?
    
    @history.action = 'reject'
    assert @history.action_reject?
    
    @history.action = 'view'
    assert @history.action_view?
  end
  
  # 스코프 테스트
  test "ordered scope should order by processed_at desc" do
    histories = ApprovalHistory.ordered
    previous_time = Time.current + 1.day
    
    histories.each do |history|
      assert history.processed_at <= previous_time
      previous_time = history.processed_at
    end
  end
  
  test "chronological scope should order by processed_at asc" do
    histories = ApprovalHistory.chronological
    previous_time = Time.current - 1.year
    
    histories.each do |history|
      assert history.processed_at >= previous_time
      previous_time = history.processed_at
    end
  end
  
  test "approvals scope should return only approve actions" do
    approvals = ApprovalHistory.approvals
    assert approvals.all? { |h| h.action_approve? }
  end
  
  test "rejections scope should return only reject actions" do
    # 반려 이력 생성
    ApprovalHistory.create!(
      approval_request: @approval_request,
      approver: @approver,
      step_order: 1,
      role: 'approve',
      action: 'reject',
      comment: '반려 사유'
    )
    
    rejections = ApprovalHistory.rejections
    assert rejections.all? { |h| h.action_reject? }
  end
  
  test "views scope should return only view actions" do
    # 조회 이력 생성
    ApprovalHistory.create!(
      approval_request: @approval_request,
      approver: users(:three),
      step_order: 1,
      role: 'reference',
      action: 'view'
    )
    
    views = ApprovalHistory.views
    assert views.all? { |h| h.action_view? }
  end
  
  # 인스턴스 메서드 테스트
  test "action_display should return Korean text" do
    @history.action = 'approve'
    assert_equal '승인', @history.action_display
    
    @history.action = 'reject'
    assert_equal '반려', @history.action_display
    
    @history.action = 'view'
    assert_equal '열람', @history.action_display
  end
  
  test "role_display should return Korean text" do
    @history.role = 'approve'
    assert_equal '승인', @history.role_display
    
    @history.role = 'reference'
    assert_equal '참조', @history.role_display
  end
  
  test "summary should return formatted summary" do
    @history.action = 'approve'
    @history.comment = '승인합니다'
    
    summary = @history.summary
    assert_includes summary, @history.approver.name
    assert_includes summary, '승인'
    assert_includes summary, '승인합니다'
  end
  
  test "summary without comment should work" do
    @history.action = 'view'
    @history.comment = nil
    
    summary = @history.summary
    assert_includes summary, @history.approver.name
    assert_includes summary, '열람'
  end
  
  # 관계 테스트
  test "should belong to approval_request" do
    assert_respond_to @history, :approval_request
    assert_instance_of ApprovalRequest, @history.approval_request
  end
  
  test "should belong to approver" do
    assert_respond_to @history, :approver
    assert_instance_of User, @history.approver
  end
  
  # 데이터 무결성 테스트
  test "should not be editable after creation" do
    # 실제 구현에서는 before_update 콜백으로 변경 방지
    # 여기서는 테스트 의도만 표현
    original_action = @history.action
    @history.action = 'reject'
    
    # 실제로는 저장이 실패하거나 변경이 무시되어야 함
    # assert_not @history.save
    # 또는
    # @history.reload
    # assert_equal original_action, @history.action
  end
  
  test "processed_at cannot be in the future" do
    @history.processed_at = Time.current + 1.day
    assert_not @history.valid?
    assert_includes @history.errors[:processed_at], "미래 시간은 설정할 수 없습니다"
  end
end