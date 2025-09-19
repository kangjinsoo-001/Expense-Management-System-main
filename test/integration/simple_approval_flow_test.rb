require "test_helper"

class SimpleApprovalFlowTest < ActionDispatch::IntegrationTest
  test "승인 프로세스 기본 플로우" do
    # 조직 생성
    organization = Organization.create!(name: "Test Org", code: "TEST")
    
    # 사용자 생성
    employee = User.create!(
      email: "emp@test.com",
      password: "password",
      name: "Employee",
      employee_id: "E001",
      role: "employee",
      organization: organization
    )
    
    manager = User.create!(
      email: "mgr@test.com",
      password: "password",
      name: "Manager",
      employee_id: "M001",
      role: "manager",
      organization: organization
    )
    
    # 경비 코드와 코스트센터 생성
    expense_code = ExpenseCode.create!(
      code: "TEST",
      name: "테스트 경비",
      description: "테스트",
      active: true,
      is_current: true,
      version: 1,
      effective_from: Date.current,
      validation_rules: { "required_fields" => {} }
    )
    
    cost_center = CostCenter.create!(
      name: "테스트 센터",
      code: "CC001",
      organization: organization
    )
    
    # 직원으로 로그인
    post login_path, params: { email: employee.email, password: "password" }
    assert_redirected_to root_path
    
    # 결재선 생성
    post approval_lines_path, params: {
      approval_line: {
        name: "테스트 결재선",
        is_active: true,
        approval_line_steps_attributes: {
          "0" => {
            approver_id: manager.id,
            step_order: 1,
            role: "approve"
          }
        }
      }
    }
    
    approval_line = employee.approval_lines.last
    assert_not_nil approval_line
    
    # 경비 시트 생성
    expense_sheet = employee.expense_sheets.create!(
      organization: organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    # 경비 항목 생성 (결재선 적용)
    expense_item = expense_sheet.expense_items.create!(
      expense_code: expense_code,
      cost_center: cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트 경비",
      vendor_name: "테스트 업체",
      approval_line: approval_line,
      custom_fields: {}
    )
    
    # 승인 요청이 생성되었는지 확인
    assert_not_nil expense_item.approval_request
    assert_equal "pending", expense_item.approval_request.status
    assert_equal 1, expense_item.approval_request.current_step
    
    # 로그아웃
    delete logout_path
    
    # 승인자로 로그인
    post login_path, params: { email: manager.email, password: "password" }
    
    # 승인 처리
    approval_request = expense_item.approval_request
    approval_request.process_approval(manager, "승인합니다")
    
    # 승인 완료 확인
    approval_request.reload
    assert_equal "approved", approval_request.status
    
    # 승인 이력 확인
    history = approval_request.approval_histories.last
    assert_equal "approve", history.action
    assert_equal "승인합니다", history.comment
    assert_equal manager, history.approver
  end
  
  test "반려 프로세스" do
    # 조직 생성
    organization = Organization.create!(name: "Test Org", code: "TEST")
    
    # 사용자 생성
    employee = User.create!(
      email: "emp2@test.com",
      password: "password",
      name: "Employee2",
      employee_id: "E002",
      role: "employee",
      organization: organization
    )
    
    manager = User.create!(
      email: "mgr2@test.com",
      password: "password",
      name: "Manager2",
      employee_id: "M002",
      role: "manager",
      organization: organization
    )
    
    # 필요한 기본 데이터 생성
    expense_code = ExpenseCode.create!(
      code: "TEST2",
      name: "테스트 경비2",
      description: "테스트2",
      active: true,
      is_current: true,
      version: 1,
      effective_from: Date.current,
      validation_rules: { "required_fields" => {} }
    )
    
    cost_center = CostCenter.create!(
      name: "테스트 센터2",
      code: "CC002",
      organization: organization
    )
    
    # 결재선 생성
    approval_line = employee.approval_lines.create!(
      name: "반려 테스트 결재선",
      is_active: true,
      approval_line_steps_attributes: {
        "0" => {
          approver_id: manager.id,
          step_order: 1,
          role: "approve"
        }
      }
    )
    
    # 경비 시트와 항목 생성
    expense_sheet = employee.expense_sheets.create!(
      organization: organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: expense_code,
      cost_center: cost_center,
      expense_date: Date.current,
      amount: 50000,
      description: "반려 테스트",
      vendor_name: "테스트",
      approval_line: approval_line,
      custom_fields: {}
    )
    
    approval_request = expense_item.approval_request
    
    # 반려 처리
    approval_request.process_rejection(manager, "증빙 부족")
    
    # 반려 확인
    approval_request.reload
    assert_equal "rejected", approval_request.status
    
    # 반려 이력 확인
    history = approval_request.approval_histories.last
    assert_equal "reject", history.action
    assert_equal "증빙 부족", history.comment
  end
end