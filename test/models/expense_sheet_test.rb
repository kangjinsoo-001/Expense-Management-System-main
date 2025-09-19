require "test_helper"

class ExpenseSheetTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @organization = organizations(:one)
    @expense_sheet = ExpenseSheet.create!(
      user: @user,
      organization: @organization,
      year: Date.current.year,
      month: Date.current.month,
      status: 'draft'
    )
  end

  test "유효한 경비 시트 생성" do
    assert @expense_sheet.valid?
  end

  test "사용자별 년월 유니크 제약" do
    duplicate_sheet = ExpenseSheet.new(
      user: @user,
      organization: @organization,
      year: @expense_sheet.year,
      month: @expense_sheet.month
    )
    
    assert_not duplicate_sheet.valid?
    assert_includes duplicate_sheet.errors[:user_id], "해당 월에 이미 경비 시트가 존재합니다"
  end

  test "상태 검증" do
    valid_statuses = %w[draft submitted approved rejected closed]
    
    valid_statuses.each do |status|
      @expense_sheet.status = status
      assert @expense_sheet.valid?
    end
    
    assert_raises(ArgumentError) do
      @expense_sheet.status = 'invalid_status'
    end
  end

  test "편집 가능 상태 확인" do
    assert @expense_sheet.editable?
    
    @expense_sheet.status = 'rejected'
    assert @expense_sheet.editable?
    
    @expense_sheet.status = 'submitted'
    assert_not @expense_sheet.editable?
    
    @expense_sheet.status = 'approved'
    assert_not @expense_sheet.editable?
    
    @expense_sheet.status = 'closed'
    assert_not @expense_sheet.editable?
  end

  test "제출 가능 여부 확인" do
    # 경비 항목이 없으면 제출 불가
    assert_not @expense_sheet.submittable?
    
    # 경비 항목 추가
    expense_code = expense_codes(:one)
    cost_center = cost_centers(:one)
    
    @expense_sheet.expense_items.create!(
      expense_code: expense_code,
      cost_center: cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트 경비",
      is_valid: true
    )
    
    assert @expense_sheet.submittable?
    
    # 제출된 상태에서는 제출 불가
    @expense_sheet.status = 'submitted'
    assert_not @expense_sheet.submittable?
  end

  test "경비 시트 제출" do
    # 유효한 경비 항목 추가
    expense_code = expense_codes(:one)
    cost_center = cost_centers(:one)
    
    @expense_sheet.expense_items.create!(
      expense_code: expense_code,
      cost_center: cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트 경비",
      is_valid: true
    )
    
    assert @expense_sheet.submit!
    assert_equal 'submitted', @expense_sheet.status
    assert_not_nil @expense_sheet.submitted_at
  end

  test "검증되지 않은 항목이 있으면 제출 실패" do
    expense_code = expense_codes(:one)
    cost_center = cost_centers(:one)
    
    item = @expense_sheet.expense_items.build(
      expense_code: expense_code,
      cost_center: cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트 경비"
    )
    item.is_valid = false  # 검증 실패 상태
    item.save!(validate: false)
    
    assert_not @expense_sheet.submit!
    assert_equal 'draft', @expense_sheet.status
    assert_includes @expense_sheet.errors[:base], "검증되지 않은 경비 항목이 1개 있습니다"
  end

  test "승인 처리" do
    @expense_sheet.update!(status: 'submitted')
    approver = users(:two)
    
    assert @expense_sheet.approve!(approver)
    assert_equal 'approved', @expense_sheet.status
    assert_equal approver, @expense_sheet.approved_by
    assert_not_nil @expense_sheet.approved_at
  end

  test "반려 처리" do
    @expense_sheet.update!(status: 'submitted')
    approver = users(:two)
    reason = "영수증 누락"
    
    assert @expense_sheet.reject!(approver, reason)
    assert_equal 'rejected', @expense_sheet.status
    assert_equal approver, @expense_sheet.approved_by
    assert_equal reason, @expense_sheet.rejection_reason
    assert_not_nil @expense_sheet.approved_at
  end

  test "마감 처리" do
    @expense_sheet.update!(status: 'approved')
    
    assert @expense_sheet.close!
    assert_equal 'closed', @expense_sheet.status
  end

  test "총액 계산" do
    expense_code = expense_codes(:one)
    cost_center = cost_centers(:one)
    
    # 여러 경비 항목 추가
    [10000, 20000, 30000].each_with_index do |amount, index|
      @expense_sheet.expense_items.create!(
        expense_code: expense_code,
        cost_center: cost_center,
        expense_date: Date.current - index.days,
        amount: amount,
        description: "테스트 경비 #{index + 1}",
        is_valid: true
      )
    end
    
    @expense_sheet.calculate_total_amount
    assert_equal 60000, @expense_sheet.total_amount
  end

  test "기본 년월 설정" do
    new_sheet = ExpenseSheet.create!(
      user: users(:two),
      organization: @organization,
      status: 'draft'
    )
    
    assert_equal Date.current.year, new_sheet.year
    assert_equal Date.current.month, new_sheet.month
  end

  test "스코프 테스트" do
    # 상태별 스코프
    draft_sheets = ExpenseSheet.by_status('draft')
    assert_includes draft_sheets, @expense_sheet
    
    # 기간별 스코프
    period_sheets = ExpenseSheet.by_period(Date.current.year, Date.current.month)
    assert_includes period_sheets, @expense_sheet
    
    # 편집 가능 상태 스코프
    editable_sheets = ExpenseSheet.editable_statuses
    assert_includes editable_sheets, @expense_sheet
    
    # 승인 대기 스코프
    @expense_sheet.update!(status: 'submitted')
    approval_sheets = ExpenseSheet.for_approval
    assert_includes approval_sheets, @expense_sheet
  end
  
  test "결재가 필요한 경비 항목 확인" do
    # 승인자 그룹 생성
    manager_group = ApproverGroup.create!(
      created_by: @user,
      name: "팀장",
      priority: 5,
      is_active: true
    )
    
    # 승인 규칙이 있는 경비 코드 생성
    expense_code_with_rules = ExpenseCode.create!(
      organization: @organization,
      code: "APPROVAL_REQ",
      name: "승인필요경비",
      version: 1
    )
    
    # 승인 규칙 추가
    ExpenseCodeApprovalRule.create!(
      expense_code: expense_code_with_rules,
      approver_group: manager_group,
      condition: "#금액 > 50000",
      order: 1,
      is_active: true
    )
    
    # 승인 규칙이 있는 경비 항목 추가
    @expense_sheet.expense_items.create!(
      expense_code: expense_code_with_rules,
      cost_center: cost_centers(:one),
      expense_date: Date.new(@expense_sheet.year, @expense_sheet.month, 15),
      amount: 100000,
      description: "승인 필요 경비",
      is_valid: true
    )
    
    assert @expense_sheet.requires_approval?
  end
  
  test "결재선 검증이 포함된 제출 프로세스" do
    # 승인자 그룹과 사용자 생성
    manager_group = ApproverGroup.create!(
      created_by: @user,
      name: "팀장그룹",
      priority: 5,
      is_active: true
    )
    
    manager_user = User.create!(
      email: "sheet_test_manager@example.com",
      password: "password123",
      name: "시트테스트매니저",
      employee_id: "STM001",
      organization: @organization
    )
    
    ApproverGroupMember.create!(
      approver_group: manager_group,
      user: manager_user,
      added_by: @user,
      added_at: Time.current
    )
    
    # 승인 규칙이 있는 경비 코드 생성
    expense_code_with_rules = ExpenseCode.create!(
      organization: @organization,
      code: "SHEET_APPROVAL",
      name: "시트승인경비",
      version: 1
    )
    
    ExpenseCodeApprovalRule.create!(
      expense_code: expense_code_with_rules,
      approver_group: manager_group,
      condition: "",  # 모든 경우에 승인 필요
      order: 1,
      is_active: true
    )
    
    # 결재선 생성
    approval_line = ApprovalLine.create!(
      name: "매니저 결재선",
      user: @user,
      approval_line_steps_attributes: [{
        step_order: 1,
        role: 'approve',
        approver_id: manager_user.id
      }]
    )
    
    @expense_sheet.update!(approval_line: approval_line)
    
    # 경비 항목 추가
    @expense_sheet.expense_items.create!(
      expense_code: expense_code_with_rules,
      cost_center: cost_centers(:one),
      expense_date: Date.new(@expense_sheet.year, @expense_sheet.month, 15),
      amount: 50000,
      description: "결재선 검증 테스트",
      is_valid: true
    )
    
    # 제출 성공
    result = @expense_sheet.submit!
    unless result
      puts "제출 실패 에러: #{@expense_sheet.errors.full_messages.join(', ')}"
    end
    assert result
    assert_equal 'submitted', @expense_sheet.status
  end
end