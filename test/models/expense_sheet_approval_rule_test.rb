require_relative "../test_without_fixtures"

class ExpenseSheetApprovalRuleTest < ActiveSupport::TestCase
  self.use_transactional_tests = true
  
  setup do
    # 테스트용 사용자 생성
    @user = User.create!(email: 'user@test.com', name: '일반사용자', password: 'password123', employee_id: 'E001')
    @manager = User.create!(email: 'manager@test.com', name: '매니저', password: 'password123', employee_id: 'E002')
    @director = User.create!(email: 'director@test.com', name: '디렉터', password: 'password123', employee_id: 'E003')
    @ceo = User.create!(email: 'ceo@test.com', name: 'CEO', password: 'password123', employee_id: 'E004')
    
    # 테스트용 조직 구조 설정
    @organization = Organization.create!(name: '본사', code: 'HQ')
    @department = Organization.create!(name: '영업팀', code: 'SALES', parent: @organization)
    
    @user.update(organization: @department)
    @manager.update(organization: @department, role: 'manager')
    @director.update(organization: @organization, role: 'admin')
    @ceo.update(organization: @organization, role: 'admin')
  end

  test "경비 코드 기반 규칙 생성" do
    rule = ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['ACC001', 'ACC002'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [
          { approver_id: @manager.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 1,
      name: '경비 코드 기반 승인 규칙'
    )

    assert rule.valid?
    assert_equal 'expense_code_based', rule.rule_type
    assert_equal ['ACC001', 'ACC002'], rule.conditions['expense_codes']
  end

  test "경비 코드가 포함된 경비 신청서 평가" do
    # 경비 코드 기반 규칙 생성
    rule = ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['TRAVEL001'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [
          { approver_id: @director.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 10,
      name: '출장비 승인 규칙'
    )

    # 경비 신청서 생성 (TRAVEL001 코드 포함)
    expense_sheet = ExpenseSheet.create!(
      user: @user,
      title: '출장 경비 신청',
      total_amount: 500000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'TRAVEL001',
          description: '출장비',
          amount: 500000
        }
      ]
    )

    # 규칙 평가
    assert rule.matches?(expense_sheet), "규칙이 경비 신청서와 매치되어야 함"
  end

  test "여러 경비 코드 중 하나라도 포함시 매치 (include_any)" do
    rule = ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['ACC001', 'ACC002', 'ACC003'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [
          { approver_id: @manager.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 1,
      name: '회계 관련 경비 승인'
    )

    # ACC002만 포함된 경비 신청서
    expense_sheet = ExpenseSheet.create!(
      user: @user,
      title: '회계 경비',
      total_amount: 100000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'ACC002',
          description: '회계 소프트웨어',
          amount: 100000
        }
      ]
    )

    assert rule.matches?(expense_sheet), "include_any: 하나라도 포함되면 매치되어야 함"
  end

  test "모든 경비 코드 포함시에만 매치 (include_all)" do
    rule = ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['MEAL001', 'TRANSPORT001'],
        expense_code_operator: 'include_all'
      },
      approval_line: {
        steps: [
          { approver_id: @manager.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 1,
      name: '식사+교통비 동시 신청'
    )

    # 두 코드 모두 포함된 경비 신청서
    expense_sheet_all = ExpenseSheet.create!(
      user: @user,
      title: '업무 경비',
      total_amount: 50000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'MEAL001',
          description: '업무 식사',
          amount: 30000
        },
        {
          expense_date: Date.today,
          expense_code: 'TRANSPORT001',
          description: '교통비',
          amount: 20000
        }
      ]
    )

    # 하나만 포함된 경비 신청서
    expense_sheet_partial = ExpenseSheet.create!(
      user: @user,
      title: '식사 경비만',
      total_amount: 30000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'MEAL001',
          description: '업무 식사',
          amount: 30000
        }
      ]
    )

    assert rule.matches?(expense_sheet_all), "include_all: 모두 포함시 매치되어야 함"
    assert_not rule.matches?(expense_sheet_partial), "include_all: 일부만 포함시 매치되지 않아야 함"
  end

  test "경비 코드 제외 조건 (exclude)" do
    rule = ExpenseSheetApprovalRule.create!(
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
      priority: 1,
      name: '제한 코드 제외 규칙'
    )

    # 제한 코드가 없는 경비 신청서
    expense_sheet_normal = ExpenseSheet.create!(
      user: @user,
      title: '일반 경비',
      total_amount: 50000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'NORMAL001',
          description: '일반 경비',
          amount: 50000
        }
      ]
    )

    # 제한 코드가 포함된 경비 신청서
    expense_sheet_restricted = ExpenseSheet.create!(
      user: @user,
      title: '제한 경비',
      total_amount: 50000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'RESTRICTED001',
          description: '제한된 경비',
          amount: 50000
        }
      ]
    )

    assert rule.matches?(expense_sheet_normal), "exclude: 제한 코드가 없으면 매치되어야 함"
    assert_not rule.matches?(expense_sheet_restricted), "exclude: 제한 코드가 있으면 매치되지 않아야 함"
  end

  test "복합 조건 평가 - 금액과 경비 코드" do
    rule = ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['HIGH_VALUE001'],
        expense_code_operator: 'include_any',
        min_amount: 1000000
      },
      approval_line: {
        steps: [
          { approver_id: @ceo.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 20,
      name: '고액 특별 경비'
    )

    # 코드는 맞지만 금액이 부족한 경우
    expense_sheet_low = ExpenseSheet.create!(
      user: @user,
      title: '소액 특별 경비',
      total_amount: 500000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'HIGH_VALUE001',
          description: '특별 경비',
          amount: 500000
        }
      ]
    )

    # 코드와 금액 모두 조건 충족
    expense_sheet_high = ExpenseSheet.create!(
      user: @user,
      title: '고액 특별 경비',
      total_amount: 2000000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'HIGH_VALUE001',
          description: '고액 특별 경비',
          amount: 2000000
        }
      ]
    )

    assert_not rule.matches?(expense_sheet_low), "금액 조건 미충족시 매치되지 않아야 함"
    assert rule.matches?(expense_sheet_high), "모든 조건 충족시 매치되어야 함"
  end

  test "우선순위에 따른 규칙 선택" do
    # 낮은 우선순위 규칙
    rule_low_priority = ExpenseSheetApprovalRule.create!(
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
      name: '일반 승인 규칙'
    )

    # 높은 우선순위 규칙
    rule_high_priority = ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['GENERAL001'],
        expense_code_operator: 'include_any',
        min_amount: 100000
      },
      approval_line: {
        steps: [
          { approver_id: @director.id, order: 1 }
        ]
      },
      is_active: true,
      priority: 10,
      name: '고액 일반 승인 규칙'
    )

    expense_sheet = ExpenseSheet.create!(
      user: @user,
      title: '일반 경비',
      total_amount: 200000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'GENERAL001',
          description: '일반 경비',
          amount: 200000
        }
      ]
    )

    matching_rules = ExpenseSheetApprovalRule.matching_rules_for(expense_sheet)
    
    assert_includes matching_rules, rule_high_priority
    assert_includes matching_rules, rule_low_priority
    assert_equal rule_high_priority, matching_rules.first, "높은 우선순위 규칙이 먼저 와야 함"
  end

  test "비활성 규칙은 평가되지 않음" do
    rule = ExpenseSheetApprovalRule.create!(
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['TEST001'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [
          { approver_id: @manager.id, order: 1 }
        ]
      },
      is_active: false,
      priority: 1,
      name: '비활성 규칙'
    )

    expense_sheet = ExpenseSheet.create!(
      user: @user,
      title: '테스트 경비',
      total_amount: 50000,
      items_attributes: [
        {
          expense_date: Date.today,
          expense_code: 'TEST001',
          description: '테스트',
          amount: 50000
        }
      ]
    )

    matching_rules = ExpenseSheetApprovalRule.matching_rules_for(expense_sheet)
    assert_not_includes matching_rules, rule, "비활성 규칙은 매칭되지 않아야 함"
  end
end