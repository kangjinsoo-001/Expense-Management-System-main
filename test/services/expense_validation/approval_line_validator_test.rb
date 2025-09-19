require "test_helper"

class ExpenseValidation::ApprovalLineValidatorTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @user = users(:one)
    
    # 승인자 그룹 생성
    @exec_group = ApproverGroup.create!(
      created_by: @user,
      name: "임원",
      priority: 10,
      is_active: true
    )
    
    @manager_group = ApproverGroup.create!(
      created_by: @user,
      name: "팀장",
      priority: 5,
      is_active: true
    )
    
    @staff_group = ApproverGroup.create!(
      created_by: @user,
      name: "직원",
      priority: 1,
      is_active: true
    )
    
    # 사용자 생성
    @exec_user = User.create!(
      email: "exec_test@example.com",
      password: "password123",
      name: "임원",
      employee_id: "EX001",
      organization: @organization
    )
    
    @manager_user = User.create!(
      email: "manager_test@example.com",
      password: "password123",
      name: "팀장",
      employee_id: "MG001",
      organization: @organization
    )
    
    # 그룹 멤버십 설정
    ApproverGroupMember.create!(
      approver_group: @exec_group, 
      user: @exec_user,
      added_by: @user,
      added_at: Time.current
    )
    ApproverGroupMember.create!(
      approver_group: @manager_group, 
      user: @manager_user,
      added_by: @user,
      added_at: Time.current
    )
    
    # 경비 코드 생성
    @expense_code = ExpenseCode.create!(
      organization: @organization,
      code: "TR001",
      name: "교통비",
      version: 1
    )
    
    # 경비 시트 생성
    @expense_sheet = ExpenseSheet.create!(
      user: @user,
      organization: @organization,
      year: 2024,
      month: 12,
      status: 'draft'
    )
    
    # 코스트 센터 생성
    @cost_center = CostCenter.create!(
      code: "CC_VALIDATOR_TEST",
      name: "검증테스트팀",
      organization: @organization,
      manager: @manager_user
    )
  end
  
  test "결재선이 없을 때는 검증 통과" do
    expense_item = ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_code: @expense_code,
      expense_date: Date.new(2024, 12, 15),
      amount: 10000,
      cost_center: @cost_center,
      description: "테스트 경비"
    )
    
    validator = ExpenseValidation::ApprovalLineValidator.new(expense_item)
    assert validator.validate
    assert_empty validator.errors
  end
  
  test "승인 규칙이 없을 때는 검증 통과" do
    # 결재선 생성
    approval_line = ApprovalLine.create!(
      name: "일반 결재선",
      user: @user,
      approval_line_steps_attributes: [{
        step_order: 1,
        role: 'approve',
        approver_id: @manager_user.id
      }]
    )
    
    @expense_sheet.update!(approval_line: approval_line)
    
    expense_item = ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_code: @expense_code,
      expense_date: Date.new(2024, 12, 15),
      amount: 10000,
      cost_center: @cost_center,
      description: "테스트 경비"
    )
    
    validator = ExpenseValidation::ApprovalLineValidator.new(expense_item)
    assert validator.validate
    assert_empty validator.errors
  end
  
  test "승인 규칙이 충족될 때 검증 통과" do
    # 승인 규칙 생성: 10만원 초과 시 팀장 승인 필요
    rule = ExpenseCodeApprovalRule.create!(
      expense_code: @expense_code,
      approver_group: @manager_group,
      condition: "#금액 > 100000",
      order: 1,
      is_active: true
    )
    
    # 결재선 생성 (팀장 포함)
    approval_line = ApprovalLine.create!(
      name: "팀장 결재선",
      user: @user,
      approval_line_steps_attributes: [{
        step_order: 1,
        role: 'approve',
        approver_id: @manager_user.id
      }]
    )
    
    @expense_sheet.update!(approval_line: approval_line)
    
    expense_item = ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_code: @expense_code,
      expense_date: Date.new(2024, 12, 15),
      amount: 150000,
      cost_center: @cost_center,
      description: "테스트 경비"
    )
    
    validator = ExpenseValidation::ApprovalLineValidator.new(expense_item)
    assert validator.validate
    assert_empty validator.errors
  end
  
  test "승인 규칙이 충족되지 않을 때 검증 실패" do
    # 승인 규칙 생성: 10만원 초과 시 임원 승인 필요
    rule = ExpenseCodeApprovalRule.create!(
      expense_code: @expense_code,
      approver_group: @exec_group,
      condition: "#금액 > 100000",
      order: 1,
      is_active: true
    )
    
    # 결재선 생성 (팀장만 포함 - 임원 없음)
    approval_line = ApprovalLine.create!(
      name: "팀장 결재선",
      user: @user,
      approval_line_steps_attributes: [{
        step_order: 1,
        role: 'approve',
        approver_id: @manager_user.id
      }]
    )
    
    @expense_sheet.update!(approval_line: approval_line)
    
    expense_item = ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_code: @expense_code,
      expense_date: Date.new(2024, 12, 15),
      amount: 150000,
      cost_center: @cost_center,
      description: "테스트 경비"
    )
    
    validator = ExpenseValidation::ApprovalLineValidator.new(expense_item)
    refute validator.validate
    assert_equal 1, validator.errors.size
    
    error_message = validator.error_messages.first
    assert_match /임원 이상의 승인이 필요합니다/, error_message
  end
  
  test "위계를 고려한 승인 규칙 검증" do
    # 승인 규칙 생성: 10만원 초과 시 팀장 승인 필요
    rule = ExpenseCodeApprovalRule.create!(
      expense_code: @expense_code,
      approver_group: @manager_group,
      condition: "#금액 > 100000",
      order: 1,
      is_active: true
    )
    
    # 결재선 생성 (임원 포함 - 팀장보다 상위)
    approval_line = ApprovalLine.create!(
      name: "임원 결재선",
      user: @user,
      approval_line_steps_attributes: [{
        step_order: 1,
        role: 'approve',
        approver_id: @exec_user.id
      }]
    )
    
    @expense_sheet.update!(approval_line: approval_line)
    
    expense_item = ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_code: @expense_code,
      expense_date: Date.new(2024, 12, 15),
      amount: 150000,
      cost_center: @cost_center,
      description: "테스트 경비"
    )
    
    # 임원이 팀장보다 상위이므로 검증 통과해야 함
    validator = ExpenseValidation::ApprovalLineValidator.new(expense_item)
    assert validator.validate
    assert_empty validator.errors
  end
  
  test "복수 승인 규칙 검증" do
    # 승인 규칙 1: 10만원 초과 시 팀장 승인 필요
    rule1 = ExpenseCodeApprovalRule.create!(
      expense_code: @expense_code,
      approver_group: @manager_group,
      condition: "#금액 > 100000",
      order: 1,
      is_active: true
    )
    
    # 승인 규칙 2: 50만원 초과 시 임원 승인 필요
    rule2 = ExpenseCodeApprovalRule.create!(
      expense_code: @expense_code,
      approver_group: @exec_group,
      condition: "#금액 > 500000",
      order: 2,
      is_active: true
    )
    
    # 결재선 생성 (팀장만 포함)
    approval_line = ApprovalLine.create!(
      name: "팀장 결재선",
      user: @user,
      approval_line_steps_attributes: [{
        step_order: 1,
        role: 'approve',
        approver_id: @manager_user.id
      }]
    )
    
    @expense_sheet.update!(approval_line: approval_line)
    
    # 60만원 경비 항목 - 두 규칙 모두 적용
    expense_item = ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_code: @expense_code,
      expense_date: Date.new(2024, 12, 15),
      amount: 600000,
      cost_center: @cost_center,
      description: "테스트 경비"
    )
    
    validator = ExpenseValidation::ApprovalLineValidator.new(expense_item)
    refute validator.validate
    assert_equal 1, validator.errors.size
    
    # 임원 승인이 필요하다는 메시지가 있어야 함
    error_message = validator.error_messages.first
    assert_match /임원/, error_message
  end
  
  test "조건 설명 변환 테스트" do
    rule = ExpenseCodeApprovalRule.create!(
      expense_code: @expense_code,
      approver_group: @manager_group,
      condition: "#금액 >= 300000",
      order: 1,
      is_active: true
    )
    
    approval_line = ApprovalLine.create!(
      name: "일반 결재선",
      user: @user,
      approval_line_steps_attributes: [{
        step_order: 1,
        role: 'approve',
        approver_id: @user.id
      }]
    )
    
    @expense_sheet.update!(approval_line: approval_line)
    
    expense_item = ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_code: @expense_code,
      expense_date: Date.new(2024, 12, 15),
      amount: 300000,
      cost_center: @cost_center,
      description: "테스트 경비"
    )
    
    validator = ExpenseValidation::ApprovalLineValidator.new(expense_item)
    refute validator.validate
    
    error_message = validator.error_messages.first
    assert_match /금액이 ₩300,000 이상인 경우/, error_message
  end
end