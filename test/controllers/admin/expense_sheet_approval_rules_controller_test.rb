require_relative "../../test_without_fixtures"

class Admin::ExpenseSheetApprovalRulesControllerTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = true
  
  setup do
    @admin = User.create!(email: 'admin@test.com', name: '관리자', password: 'password123', employee_id: 'E100')
    @manager = User.create!(email: 'manager@test.com', name: '매니저', password: 'password123', employee_id: 'E101')
    @director = User.create!(email: 'director@test.com', name: '디렉터', password: 'password123', employee_id: 'E102')
    
    sign_in @admin
  end

  test "경비 코드 기반 규칙 생성" do
    assert_difference('ExpenseSheetApprovalRule.count') do
      post admin_expense_sheet_approval_rules_path, params: {
        expense_sheet_approval_rule: {
          name: '출장비 승인 규칙',
          rule_type: 'expense_code_based',
          conditions: {
            expense_codes: ['TRAVEL001', 'TRAVEL002'],
            expense_code_operator: 'include_any'
          },
          approval_line: {
            steps: [
              { approver_id: @manager.id, order: 1 }
            ]
          },
          priority: 10,
          is_active: true
        }
      }, as: :json
    end

    rule = ExpenseSheetApprovalRule.last
    assert_equal 'expense_code_based', rule.rule_type
    assert_equal ['TRAVEL001', 'TRAVEL002'], rule.conditions['expense_codes']
    assert_equal 'include_any', rule.conditions['expense_code_operator']
    assert_response :success
  end

  test "복합 조건으로 경비 코드 규칙 생성" do
    assert_difference('ExpenseSheetApprovalRule.count') do
      post admin_expense_sheet_approval_rules_path, params: {
        expense_sheet_approval_rule: {
          name: '고액 프로젝트 경비',
          rule_type: 'expense_code_based',
          conditions: {
            expense_codes: ['PROJECT001', 'PROJECT002'],
            expense_code_operator: 'include_any',
            min_amount: 1000000,
            max_amount: 10000000
          },
          approval_line: {
            steps: [
              { approver_id: @manager.id, order: 1 },
              { approver_id: @director.id, order: 2 }
            ]
          },
          priority: 15,
          is_active: true
        }
      }, as: :json
    end

    rule = ExpenseSheetApprovalRule.last
    assert_equal 1000000, rule.conditions['min_amount']
    assert_equal 10000000, rule.conditions['max_amount']
    assert_equal 2, rule.approval_line['steps'].size
  end

  test "모든 코드 포함 조건으로 규칙 생성" do
    assert_difference('ExpenseSheetApprovalRule.count') do
      post admin_expense_sheet_approval_rules_path, params: {
        expense_sheet_approval_rule: {
          name: '전체 출장 패키지',
          rule_type: 'expense_code_based',
          conditions: {
            expense_codes: ['MEAL001', 'TRANSPORT001', 'ACCOMMODATION001'],
            expense_code_operator: 'include_all'
          },
          approval_line: {
            steps: [
              { approver_id: @director.id, order: 1 }
            ]
          },
          priority: 20,
          is_active: true
        }
      }, as: :json
    end

    rule = ExpenseSheetApprovalRule.last
    assert_equal 'include_all', rule.conditions['expense_code_operator']
    assert_equal 3, rule.conditions['expense_codes'].size
  end

  test "제외 조건으로 규칙 생성" do
    assert_difference('ExpenseSheetApprovalRule.count') do
      post admin_expense_sheet_approval_rules_path, params: {
        expense_sheet_approval_rule: {
          name: '일반 경비 (제한 코드 제외)',
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
          priority: 5,
          is_active: true
        }
      }, as: :json
    end

    rule = ExpenseSheetApprovalRule.last
    assert_equal 'exclude', rule.conditions['expense_code_operator']
  end

  test "경비 코드 기반 규칙 수정" do
    rule = ExpenseSheetApprovalRule.create!(
      name: '기존 규칙',
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['OLD001'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [
          { approver_id: @manager.id, order: 1 }
        ]
      },
      priority: 1,
      is_active: true
    )

    patch admin_expense_sheet_approval_rule_path(rule), params: {
      expense_sheet_approval_rule: {
        conditions: {
          expense_codes: ['NEW001', 'NEW002'],
          expense_code_operator: 'include_all'
        }
      }
    }, as: :json

    rule.reload
    assert_equal ['NEW001', 'NEW002'], rule.conditions['expense_codes']
    assert_equal 'include_all', rule.conditions['expense_code_operator']
    assert_response :success
  end

  test "규칙 목록 조회" do
    # 여러 타입의 규칙 생성
    ExpenseSheetApprovalRule.create!(
      name: '금액 기반 규칙',
      rule_type: 'amount_based',
      conditions: { min_amount: 100000 },
      approval_line: { steps: [{ approver_id: @manager.id, order: 1 }] },
      priority: 1,
      is_active: true
    )

    ExpenseSheetApprovalRule.create!(
      name: '경비 코드 기반 규칙',
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['CODE001'],
        expense_code_operator: 'include_any'
      },
      approval_line: { steps: [{ approver_id: @director.id, order: 1 }] },
      priority: 10,
      is_active: true
    )

    get admin_expense_sheet_approval_rules_path, as: :json
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['rules'].any? { |r| r['rule_type'] == 'expense_code_based' }
    assert response_data['rules'].any? { |r| r['rule_type'] == 'amount_based' }
  end

  test "규칙 삭제" do
    rule = ExpenseSheetApprovalRule.create!(
      name: '삭제할 규칙',
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['DELETE001'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [{ approver_id: @manager.id, order: 1 }]
      },
      priority: 1,
      is_active: true
    )

    assert_difference('ExpenseSheetApprovalRule.count', -1) do
      delete admin_expense_sheet_approval_rule_path(rule), as: :json
    end

    assert_response :no_content
  end

  test "규칙 활성화/비활성화" do
    rule = ExpenseSheetApprovalRule.create!(
      name: '토글 규칙',
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['TOGGLE001'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [{ approver_id: @manager.id, order: 1 }]
      },
      priority: 1,
      is_active: true
    )

    # 비활성화
    patch admin_expense_sheet_approval_rule_path(rule), params: {
      expense_sheet_approval_rule: { is_active: false }
    }, as: :json

    rule.reload
    assert_not rule.is_active
    assert_response :success

    # 다시 활성화
    patch admin_expense_sheet_approval_rule_path(rule), params: {
      expense_sheet_approval_rule: { is_active: true }
    }, as: :json

    rule.reload
    assert rule.is_active
    assert_response :success
  end

  test "잘못된 조건으로 규칙 생성 실패" do
    # 경비 코드 없이 생성 시도
    assert_no_difference('ExpenseSheetApprovalRule.count') do
      post admin_expense_sheet_approval_rules_path, params: {
        expense_sheet_approval_rule: {
          name: '잘못된 규칙',
          rule_type: 'expense_code_based',
          conditions: {
            expense_code_operator: 'include_any'
            # expense_codes 누락
          },
          approval_line: {
            steps: [{ approver_id: @manager.id, order: 1 }]
          },
          priority: 1,
          is_active: true
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "우선순위 중복 처리" do
    # 기존 규칙
    ExpenseSheetApprovalRule.create!(
      name: '기존 우선순위 10',
      rule_type: 'expense_code_based',
      conditions: {
        expense_codes: ['EXIST001'],
        expense_code_operator: 'include_any'
      },
      approval_line: {
        steps: [{ approver_id: @manager.id, order: 1 }]
      },
      priority: 10,
      is_active: true
    )

    # 같은 우선순위로 새 규칙 생성 (허용됨)
    assert_difference('ExpenseSheetApprovalRule.count') do
      post admin_expense_sheet_approval_rules_path, params: {
        expense_sheet_approval_rule: {
          name: '새 우선순위 10',
          rule_type: 'expense_code_based',
          conditions: {
            expense_codes: ['NEW001'],
            expense_code_operator: 'include_any'
          },
          approval_line: {
            steps: [{ approver_id: @director.id, order: 1 }]
          },
          priority: 10,
          is_active: true
        }
      }, as: :json
    end

    assert_response :success
    assert_equal 2, ExpenseSheetApprovalRule.where(priority: 10).count
  end

  private

  def sign_in(user)
    post sessions_path, params: { 
      session: { 
        email: user.email, 
        password: 'password123' 
      } 
    }
  end
end