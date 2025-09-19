require_relative "../test_without_fixtures"

class ExpenseSheetApprovalValidatorTest < ActiveSupport::TestCase
  self.use_transactional_tests = true
  
  setup do
    @validator = ExpenseSheetApprovalValidator.new
    
    # 테스트용 사용자 생성
    @user = User.create!(email: 'user@test.com', name: '일반사용자', password: 'password123', employee_id: 'E001')
    @manager = User.create!(email: 'manager@test.com', name: '매니저', password: 'password123', employee_id: 'E002')
    @director = User.create!(email: 'director@test.com', name: '디렉터', password: 'password123', employee_id: 'E003')
    @ceo = User.create!(email: 'ceo@test.com', name: 'CEO', password: 'password123', employee_id: 'E004')
    
    # 조직 구조 설정
    @organization = Organization.create!(name: '본사', code: 'HQ')
    @department = Organization.create!(name: '영업팀', code: 'SALES', parent: @organization)
    
    @user.update(organization: @department)
    @manager.update(organization: @department, role: 'manager')
    @director.update(organization: @organization, role: 'admin')
    @ceo.update(organization: @organization, role: 'admin')
  end

  test "경비 코드 기반 규칙에 따른 승인자 요구" do
    # 출장비 코드에 대한 승인 규칙 생성
    ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['TRAVEL001', 'TRAVEL002'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [
          { approver_id: @director.id, order: 1 },
          { approver_id: @ceo.id, order: 2 }
        ]
      },
      is_active: true,
      priority: 10,
      name: '출장비 승인 규칙'
    )

    # 출장비가 포함된 경비 신청서
    expense_sheet = ExpenseSheet.create!(
      user: @user,
      title: '해외 출장 경비',
      total_amount: 3000000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'TRAVEL001',
          description: '항공료',
          amount: 2000000
        },
        {
          expense_date: Date.today,
          expense_code: 'TRAVEL002',
          description: '호텔비',
          amount: 1000000
        }
      ]
    )

    # 잘못된 승인 라인 (매니저만 포함)
    invalid_approval_line = ApprovalLine.new(
      user: @user,
      approvable: expense_sheet,
      approval_line_steps_attributes: [
        { approver: @manager, order: 1 }
      ]
    )

    result = @validator.validate(expense_sheet, invalid_approval_line)
    assert_not result[:valid], "출장비 규칙에 맞지 않는 승인자는 거부되어야 함"
    assert_includes result[:errors].join(' '), '승인자'
    
    # 올바른 승인 라인 (디렉터와 CEO 포함)
    valid_approval_line = ApprovalLine.new(
      user: @user,
      approvable: expense_sheet,
      approval_line_steps_attributes: [
        { approver: @director, order: 1 },
        { approver: @ceo, order: 2 }
      ]
    )

    result = @validator.validate(expense_sheet, valid_approval_line)
    assert result[:valid], "출장비 규칙에 맞는 승인자는 승인되어야 함"
  end

  test "복수의 경비 코드 규칙 중 가장 높은 우선순위 적용" do
    # 일반 경비 규칙 (낮은 우선순위)
    ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['GENERAL001'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [
          { approver_id: @manager.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 1,
      name: '일반 경비 승인'
    )

    # 특별 경비 규칙 (높은 우선순위)
    ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['GENERAL001'],
        expense_code_operator: 'include_any',
        min_amount: 500000
      },
      approval_line: {
        steps: [
          { approver_id: @director.id, order: 1 },
          { approver_id: @ceo.id, order: 2 }
        ]
      },
      is_active: true,
      priority: 10,
      name: '고액 일반 경비 승인'
    )

    # 고액 경비 신청서
    expense_sheet = ExpenseSheet.create!(
      user: @user,
      title: '고액 일반 경비',
      total_amount: 1000000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'GENERAL001',
          description: '고액 구매',
          amount: 1000000
        }
      ]
    )

    # 매니저만 포함한 승인 라인 (낮은 우선순위 규칙)
    low_priority_line = ApprovalLine.new(
      user: @user,
      approvable: expense_sheet,
      approval_line_steps_attributes: [
        { approver: @manager, order: 1 }
      ]
    )

    result = @validator.validate(expense_sheet, low_priority_line)
    assert_not result[:valid], "고액 경비는 높은 우선순위 규칙이 적용되어야 함"

    # 디렉터와 CEO를 포함한 승인 라인 (높은 우선순위 규칙)
    high_priority_line = ApprovalLine.new(
      user: @user,
      approvable: expense_sheet,
      approval_line_steps_attributes: [
        { approver: @director, order: 1 },
        { approver: @ceo, order: 2 }
      ]
    )

    result = @validator.validate(expense_sheet, high_priority_line)
    assert result[:valid], "높은 우선순위 규칙에 맞는 승인자는 승인되어야 함"
  end

  test "제외 조건 경비 코드 처리" do
    # 제한된 경비 코드 제외 규칙
    ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['RESTRICTED001', 'RESTRICTED002'],
        expense_code_operator: 'exclude'
      },
      approval_line: {
        steps: [
          { approver_id: @manager.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 5,
      name: '일반 승인 (제한 코드 제외)'
    )

    # CEO 승인이 필요한 제한 코드 규칙
    ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['RESTRICTED001'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [
          { approver_id: @ceo.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 10,
      name: '제한 경비 CEO 승인'
    )

    # 제한된 코드가 포함된 경비
    restricted_expense = ExpenseSheet.create!(
      user: @user,
      title: '제한 경비',
      total_amount: 100000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'RESTRICTED001',
          description: '제한 항목',
          amount: 100000
        }
      ]
    )

    # 매니저 승인 시도
    manager_line = ApprovalLine.new(
      user: @user,
      approvable: restricted_expense,
      approval_line_steps_attributes: [
        { approver: @manager, order: 1 }
      ]
    )

    result = @validator.validate(restricted_expense, manager_line)
    assert_not result[:valid], "제한 코드는 CEO 승인이 필요함"

    # CEO 승인 시도
    ceo_line = ApprovalLine.new(
      user: @user,
      approvable: restricted_expense,
      approval_line_steps_attributes: [
        { approver: @ceo, order: 1 }
      ]
    )

    result = @validator.validate(restricted_expense, ceo_line)
    assert result[:valid], "제한 코드 CEO 승인은 유효해야 함"
  end

  test "경비 코드가 없는 경우 기본 규칙 적용" do
    # 기본 규칙
    ExpenseSheetApprovalRule.create!(
      rule_type: 'amount_based',
      conditions: {
        min_amount: 0,
        max_amount: 100000
      },
      approval_line: {
        steps: [
          { approver_id: @manager.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 1,
      name: '소액 기본 승인'
    )

    # 경비 코드가 없는 신청서
    expense_sheet = ExpenseSheet.create!(
      user: @user,
      title: '기타 경비',
      total_amount: 50000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: nil,
          description: '기타 비용',
          amount: 50000
        }
      ]
    )

    approval_line = ApprovalLine.new(
      user: @user,
      approvable: expense_sheet,
      approval_line_steps_attributes: [
        { approver: @manager, order: 1 }
      ]
    )

    result = @validator.validate(expense_sheet, approval_line)
    assert result[:valid], "경비 코드가 없을 때는 기본 규칙이 적용되어야 함"
  end

  test "복합 조건 검증 - 경비 코드와 금액" do
    ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['PROJECT001'],
        expense_code_operator: 'include_any',
        min_amount: 1000000,
        max_amount: 5000000
      },
      approval_line: {
        steps: [
          { approver_id: @director.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 10,
      name: '프로젝트 경비 중액 승인'
    )

    # 조건에 맞는 경비
    valid_expense = ExpenseSheet.create!(
      user: @user,
      title: '프로젝트 경비',
      total_amount: 2000000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'PROJECT001',
          description: '프로젝트 비용',
          amount: 2000000
        }
      ]
    )

    # 금액이 범위를 벗어난 경비
    invalid_expense = ExpenseSheet.create!(
      user: @user,
      title: '프로젝트 경비 (고액)',
      total_amount: 6000000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'PROJECT001',
          description: '프로젝트 비용',
          amount: 6000000
        }
      ]
    )

    director_line = ApprovalLine.new(
      user: @user,
      approvable: valid_expense,
      approval_line_steps_attributes: [
        { approver: @director, order: 1 }
      ]
    )

    result = @validator.validate(valid_expense, director_line)
    assert result[:valid], "조건에 맞는 경비는 승인되어야 함"

    director_line_invalid = ApprovalLine.new(
      user: @user,
      approvable: invalid_expense,
      approval_line_steps_attributes: [
        { approver: @director, order: 1 }
      ]
    )

    result = @validator.validate(invalid_expense, director_line_invalid)
    # 금액이 범위를 벗어나면 이 규칙은 적용되지 않음
    assert_equal false, result[:valid] || 
      ExpenseSheetApprovalRule.matching_rules_for(invalid_expense).exclude?(
        ExpenseSheetApprovalRule.find_by(name: '프로젝트 경비 중액 승인')
      ), "금액 범위를 벗어난 경비는 이 규칙이 적용되지 않아야 함"
  end

  test "모든 코드 포함 조건 검증" do
    ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['MEAL001', 'TRANSPORT001', 'ACCOMMODATION001'],
        expense_code_operator: 'include_all'
      },
      approval_line: {
        steps: [
          { approver_id: @director.id, order: 1 },
          { approver_id: @ceo.id, order: 2 }
        ]
      },
      is_active: true,
      priority: 15,
      name: '출장 전체 패키지 승인'
    )

    # 모든 코드를 포함한 경비
    complete_expense = ExpenseSheet.create!(
      user: @user,
      title: '출장 전체 비용',
      total_amount: 500000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'MEAL001',
          description: '식비',
          amount: 50000
        },
        {
          expense_date: Date.today,
          expense_code: 'TRANSPORT001',
          description: '교통비',
          amount: 150000
        },
        {
          expense_date: Date.today,
          expense_code: 'ACCOMMODATION001',
          description: '숙박비',
          amount: 300000
        }
      ]
    )

    # 일부만 포함한 경비
    partial_expense = ExpenseSheet.create!(
      user: @user,
      title: '부분 출장 비용',
      total_amount: 200000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'MEAL001',
          description: '식비',
          amount: 50000
        },
        {
          expense_date: Date.today,
          expense_code: 'TRANSPORT001',
          description: '교통비',
          amount: 150000
        }
      ]
    )

    complete_line = ApprovalLine.new(
      user: @user,
      approvable: complete_expense,
      approval_line_steps_attributes: [
        { approver: @director, order: 1 },
        { approver: @ceo, order: 2 }
      ]
    )

    result = @validator.validate(complete_expense, complete_line)
    assert result[:valid], "모든 코드를 포함한 경비는 승인되어야 함"

    # 부분 경비에 대해서는 이 규칙이 적용되지 않음
    matching_rules = ExpenseSheetApprovalRule.matching_rules_for(partial_expense)
    full_package_rule = ExpenseSheetApprovalRule.find_by(name: '출장 전체 패키지 승인')
    assert_not_includes matching_rules, full_package_rule, 
                       "일부 코드만 포함한 경비는 전체 패키지 규칙이 적용되지 않아야 함"
  end
end