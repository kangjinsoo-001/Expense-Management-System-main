require "test_helper"

class ApprovalWorkflowTest < ActionDispatch::IntegrationTest
  # fixture를 로드하지 않음
  def self.fixtures(*table_names)
    # fixture 로드 비활성화
  end
  
  setup do
    # 조직 생성
    @organization = Organization.create!(
      name: "Test Organization",
      code: "TEST"
    )
    
    # 테스트 사용자 생성
    @employee = User.create!(
      email: "employee@test.com",
      password: "password",
      name: "Employee",
      employee_id: "EMP001",
      role: "employee",
      organization: @organization
    )
    
    @team_leader = User.create!(
      email: "teamleader@test.com",
      password: "password",
      name: "Team Leader",
      employee_id: "TL001",
      role: "manager",
      organization: @organization
    )
    
    @dept_manager = User.create!(
      email: "deptmanager@test.com",
      password: "password",
      name: "Dept Manager",
      employee_id: "DM001",
      role: "admin",
      organization: @organization
    )
    
    @ceo = User.create!(
      email: "ceo@test.com",
      password: "password",
      name: "CEO",
      employee_id: "CEO001",
      role: "admin",
      organization: @organization
    )
    
    # 경비 코드와 코스트센터
    @expense_code = ExpenseCode.create!(
      code: "OTME",
      name: "초과근무 식대",
      description: "야근 식대",
      active: true,
      is_current: true,
      version: 1,
      effective_from: Date.current,
      validation_rules: {
        "required_fields" => {
          "attendees" => { "label" => "참석자", "type" => "text", "required" => true },
          "reason" => { "label" => "사유", "type" => "text", "required" => true }
        }
      }
    )
    
    @cost_center = CostCenter.create!(
      name: "개발팀",
      code: "DEV001",
      organization: @organization,
      budget: 1000000
    )
  end

  test "전체 승인 프로세스 플로우 - 단일 승인자" do
    # 1. 직원이 로그인하여 결재선 생성
    log_in_as(@employee)
    
    # 결재선 생성
    post approval_lines_path, params: {
      approval_line: {
        name: "단일 승인 결재선",
        is_active: true,
        approval_line_steps_attributes: {
          "0" => {
            approver_id: @team_leader.id,
            step_order: 1,
            role: "approve"
          }
        }
      }
    }
    
    assert_redirected_to approval_lines_path
    approval_line = @employee.approval_lines.last
    assert_equal "단일 승인 결재선", approval_line.name
    
    # 2. 경비 시트 및 경비 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @employee.organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    # 결재선이 적용된 경비 항목 생성
    post expense_items_path, params: {
      expense_item: {
        expense_sheet_id: expense_sheet.id,
        expense_code_id: @expense_code.id,
        cost_center_id: @cost_center.id,
        expense_date: Date.current,
        amount: 15000,
        description: "야근 식대",
        vendor_name: "김밥천국",
        approval_line_id: approval_line.id,
        custom_fields: {
          "attendees" => "김철수, 이영희",
          "reason" => "프로젝트 마감"
        }
      }
    }
    
    assert_redirected_to expense_sheets_path
    expense_item = expense_sheet.expense_items.last
    assert_not_nil expense_item.approval_request
    assert_equal "pending", expense_item.approval_request.status
    
    # 3. 승인자로 로그인하여 승인 처리
    log_in_as(@team_leader)
    
    # 승인 대기 목록 확인
    get approvals_path
    assert_response :success
    assert_select "td", text: /야근 식대/
    
    # 승인 상세 화면
    get approval_path(expense_item.approval_request)
    assert_response :success
    assert_select "button", text: "승인"
    
    # 승인 처리
    post approve_approval_path(expense_item.approval_request), params: {
      comment: "확인했습니다."
    }
    
    assert_redirected_to approvals_path
    expense_item.reload
    assert_equal "approved", expense_item.approval_request.status
  end

  test "다단계 승인 프로세스 - 전체 승인 필요" do
    log_in_as(@employee)
    
    # 2단계 결재선 생성
    post approval_lines_path, params: {
      approval_line: {
        name: "2단계 결재선",
        is_active: true,
        approval_line_steps_attributes: {
          "0" => {
            approver_id: @team_leader.id,
            step_order: 1,
            role: "approve"
          },
          "1" => {
            approver_id: @dept_manager.id,
            step_order: 2,
            role: "approve"
          }
        }
      }
    }
    
    approval_line = @employee.approval_lines.last
    
    # 경비 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @employee.organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 30000,
      description: "팀 회식",
      vendor_name: "한우명가",
      approval_line: approval_line,
      custom_fields: {
        "attendees" => "팀 전체",
        "reason" => "프로젝트 성공"
      }
    )
    
    approval_request = expense_item.approval_request
    assert_equal 1, approval_request.current_step
    
    # 1차 승인자(팀장) 승인
    log_in_as(@team_leader)
    post approve_approval_path(approval_request), params: {
      comment: "1차 승인"
    }
    
    approval_request.reload
    assert_equal 2, approval_request.current_step
    assert_equal "pending", approval_request.status
    
    # 2차 승인자(부서장) 승인
    log_in_as(@dept_manager)
    post approve_approval_path(approval_request), params: {
      comment: "최종 승인"
    }
    
    approval_request.reload
    assert_equal "approved", approval_request.status
    assert_equal 2, approval_request.current_step
  end

  test "병렬 승인 프로세스 - 전체 승인 필요" do
    log_in_as(@employee)
    
    # 병렬 승인 결재선 생성 (같은 단계에 여러 승인자)
    post approval_lines_path, params: {
      approval_line: {
        name: "병렬 승인 결재선",
        is_active: true,
        approval_line_steps_attributes: {
          "0" => {
            approver_id: @team_leader.id,
            step_order: 1,
            role: "approve",
            approval_type: "all_required"
          },
          "1" => {
            approver_id: @dept_manager.id,
            step_order: 1,
            role: "approve",
            approval_type: "all_required"
          }
        }
      }
    }
    
    approval_line = @employee.approval_lines.last
    
    # 경비 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @employee.organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 50000,
      description: "부서 워크샵",
      vendor_name: "리조트",
      approval_line: approval_line,
      custom_fields: {
        "attendees" => "부서 전체",
        "reason" => "연간 워크샵"
      }
    )
    
    approval_request = expense_item.approval_request
    
    # 첫 번째 승인자 승인
    log_in_as(@team_leader)
    post approve_approval_path(approval_request), params: {
      comment: "팀장 승인"
    }
    
    approval_request.reload
    assert_equal "pending", approval_request.status # 아직 전체 승인 안됨
    assert_equal 1, approval_request.current_step
    
    # 두 번째 승인자 승인
    log_in_as(@dept_manager)
    post approve_approval_path(approval_request), params: {
      comment: "부서장 승인"
    }
    
    approval_request.reload
    assert_equal "approved", approval_request.status # 전체 승인 완료
  end

  test "단일 승인 가능 프로세스" do
    log_in_as(@employee)
    
    # 단일 승인 가능 결재선 생성
    post approval_lines_path, params: {
      approval_line: {
        name: "선택적 승인 결재선",
        is_active: true,
        approval_line_steps_attributes: {
          "0" => {
            approver_id: @team_leader.id,
            step_order: 1,
            role: "approve",
            approval_type: "single_allowed"
          },
          "1" => {
            approver_id: @dept_manager.id,
            step_order: 1,
            role: "approve",
            approval_type: "single_allowed"
          }
        }
      }
    }
    
    approval_line = @employee.approval_lines.last
    
    # 경비 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @employee.organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 20000,
      description: "긴급 구매",
      vendor_name: "사무용품점",
      approval_line: approval_line,
      custom_fields: {
        "attendees" => "김철수",
        "reason" => "긴급 필요"
      }
    )
    
    approval_request = expense_item.approval_request
    
    # 한 명만 승인해도 완료
    log_in_as(@dept_manager)
    post approve_approval_path(approval_request), params: {
      comment: "긴급 승인"
    }
    
    approval_request.reload
    assert_equal "approved", approval_request.status
  end

  test "반려 시 프로세스 중단" do
    log_in_as(@employee)
    
    # 2단계 결재선 생성
    approval_line = @employee.approval_lines.create!(
      name: "반려 테스트 결재선",
      is_active: true
    )
    
    approval_line.approval_line_steps.create!([
      { approver: @team_leader, step_order: 1, role: "approve" },
      { approver: @dept_manager, step_order: 2, role: "approve" }
    ])
    
    # 경비 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @employee.organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 100000, # 높은 금액
      description: "의심스러운 경비",
      vendor_name: "Unknown",
      approval_line: approval_line,
      custom_fields: {
        "attendees" => "?",
        "reason" => "?"
      }
    )
    
    approval_request = expense_item.approval_request
    
    # 1차 승인자가 반려
    log_in_as(@team_leader)
    post reject_approval_path(approval_request), params: {
      comment: "증빙 부족으로 반려합니다."
    }
    
    approval_request.reload
    assert_equal "rejected", approval_request.status
    assert_equal 1, approval_request.current_step # 1단계에서 중단
    
    # 반려 이력 확인
    rejection = approval_request.approval_histories.last
    assert_equal "reject", rejection.action
    assert_equal "증빙 부족으로 반려합니다.", rejection.comment
  end

  test "참조자 권한 테스트" do
    log_in_as(@employee)
    
    # 참조자 포함 결재선 생성
    approval_line = @employee.approval_lines.create!(
      name: "참조자 포함 결재선",
      is_active: true
    )
    
    approval_line.approval_line_steps.create!([
      { approver: @team_leader, step_order: 1, role: "approve" },
      { approver: @dept_manager, step_order: 1, role: "reference" }, # 참조자
      { approver: @ceo, step_order: 2, role: "approve" }
    ])
    
    # 경비 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @employee.organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 30000,
      description: "중요 회의 비용",
      vendor_name: "호텔",
      approval_line: approval_line,
      custom_fields: {
        "attendees" => "임원진",
        "reason" => "전략 회의"
      }
    )
    
    approval_request = expense_item.approval_request
    
    # 참조자로 로그인
    log_in_as(@dept_manager)
    
    # 참조 목록에서 확인
    get approvals_path
    assert_response :success
    # 참조 탭에서 항목 확인
    
    # 상세 화면 접근
    get approval_path(approval_request)
    assert_response :success
    
    # 승인/반려 버튼이 없어야 함
    assert_select "button", text: "승인", count: 0
    assert_select "button", text: "반려", count: 0
    
    # 참조자는 열람만 가능
    assert_select ".alert", text: /참조자로 지정되어 있습니다/
    
    # 열람 이력 생성 확인
    view_history = approval_request.approval_histories.find_by(
      approver: @dept_manager,
      action: "view"
    )
    assert_not_nil view_history
  end

  test "결재선 삭제 시 진행중인 승인 확인" do
    log_in_as(@employee)
    
    # 결재선 생성
    approval_line = @employee.approval_lines.create!(
      name: "삭제 테스트 결재선",
      is_active: true
    )
    
    approval_line.approval_line_steps.create!(
      approver: @team_leader,
      step_order: 1,
      role: "approve"
    )
    
    # 경비 항목에 결재선 적용
    expense_sheet = @employee.expense_sheets.create!(
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 15000,
      description: "테스트 경비",
      vendor_name: "테스트",
      approval_line: approval_line,
      custom_fields: {
        "attendees" => "테스트",
        "reason" => "테스트"
      }
    )
    
    # 진행중인 승인이 있으면 삭제 불가
    assert_raises(ActiveRecord::RecordNotDestroyed) do
      approval_line.destroy!
    end
    
    # 승인 완료 후에는 삭제 가능
    expense_item.approval_request.update!(status: "approved")
    assert_difference "ApprovalLine.count", -1 do
      approval_line.destroy!
    end
  end

  private

  def log_in_as(user)
    post login_path, params: {
      email: user.email,
      password: "password"
    }
  end
end