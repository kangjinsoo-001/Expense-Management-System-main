require "test_helper"

class ExpenseSheetStateTransitionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @expense_sheet = expense_sheets(:draft_sheet)
    @expense_code = expense_codes(:transportation)
    @cost_center = cost_centers(:one)
  end

  test "제출 가능한 상태 확인" do
    # 빈 시트는 제출 불가
    assert_not @expense_sheet.submittable?
    
    # 경비 항목 추가
    @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트",
      is_valid: true,
      custom_fields: {}
    )
    
    assert @expense_sheet.submittable?
  end

  test "draft 상태에서 submitted로 전환" do
    # 유효한 경비 항목 추가
    @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트",
      is_valid: true,
      custom_fields: {}
    )
    
    assert_changes -> { @expense_sheet.status }, from: "draft", to: "submitted" do
      assert @expense_sheet.submit!(@user)
    end
    
    assert_not_nil @expense_sheet.submitted_at
    assert_equal 1, @expense_sheet.audit_logs.count
    assert_equal "submit", @expense_sheet.audit_logs.last.action
  end

  test "검증되지 않은 항목이 있으면 제출 불가" do
    # 무효한 경비 항목 추가
    item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트",
      custom_fields: {}
    )
    
    # is_valid를 false로 직접 업데이트
    item.update_column(:is_valid, false)
    
    # 관계 리로드
    @expense_sheet.reload
    
    assert_not @expense_sheet.submit!(@user)
    assert_equal "draft", @expense_sheet.status
    assert_includes @expense_sheet.errors[:base], "검증되지 않은 경비 항목이 1개 있습니다"
  end

  test "submitted 상태에서 approved로 전환" do
    @expense_sheet.update!(status: "submitted")
    approver = users(:manager)
    
    assert_changes -> { @expense_sheet.status }, from: "submitted", to: "approved" do
      assert @expense_sheet.approve!(approver)
    end
    
    assert_not_nil @expense_sheet.approved_at
    assert_equal approver, @expense_sheet.approved_by
    assert_equal "approve", @expense_sheet.audit_logs.last.action
  end

  test "submitted 상태에서 rejected로 전환" do
    @expense_sheet.update!(status: "submitted")
    approver = users(:manager)
    reason = "영수증 누락"
    
    assert_changes -> { @expense_sheet.status }, from: "submitted", to: "rejected" do
      assert @expense_sheet.reject!(approver, reason)
    end
    
    assert_not_nil @expense_sheet.approved_at
    assert_equal approver, @expense_sheet.approved_by
    assert_equal reason, @expense_sheet.rejection_reason
    assert_equal "reject", @expense_sheet.audit_logs.last.action
    assert_equal reason, @expense_sheet.audit_logs.last.metadata["reason"]
  end

  test "approved 상태에서 closed로 전환" do
    @expense_sheet.update!(status: "approved")
    
    assert_changes -> { @expense_sheet.status }, from: "approved", to: "closed" do
      assert @expense_sheet.close!
    end
    
    assert_equal "close", @expense_sheet.audit_logs.last.action
  end

  test "편집 가능 상태 확인" do
    # draft와 rejected는 편집 가능
    @expense_sheet.update!(status: "draft")
    assert @expense_sheet.editable?
    
    @expense_sheet.update!(status: "rejected")
    assert @expense_sheet.editable?
    
    # 나머지는 편집 불가
    %w[submitted approved closed].each do |status|
      @expense_sheet.update!(status: status)
      assert_not @expense_sheet.editable?
    end
  end
end