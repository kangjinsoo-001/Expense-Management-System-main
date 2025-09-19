require "test_helper"

class ConcurrencyControlTest < ActionDispatch::IntegrationTest
  setup do
    # 조직 생성
    @organization = Organization.create!(name: "Test Org", code: "TEST")
    
    # 사용자 생성
    @employee = User.create!(
      email: "emp@test.com",
      password: "password",
      name: "Employee",
      employee_id: "E001",
      role: "employee",
      organization: @organization
    )
    
    @approver1 = User.create!(
      email: "app1@test.com",
      password: "password",
      name: "Approver 1",
      employee_id: "A001",
      role: "manager",
      organization: @organization
    )
    
    @approver2 = User.create!(
      email: "app2@test.com",
      password: "password",
      name: "Approver 2",
      employee_id: "A002",
      role: "manager",
      organization: @organization
    )
    
    @approver3 = User.create!(
      email: "app3@test.com",
      password: "password",
      name: "Approver 3",
      employee_id: "A003",
      role: "manager",
      organization: @organization
    )
    
    # 경비 코드와 코스트센터 생성
    @expense_code = ExpenseCode.create!(
      code: "TEST",
      name: "테스트 경비",
      description: "테스트",
      active: true,
      is_current: true,
      version: 1,
      effective_from: Date.current,
      validation_rules: { "required_fields" => {} }
    )
    
    @cost_center = CostCenter.create!(
      name: "테스트 센터",
      code: "CC001",
      organization: @organization
    )
  end

  test "전체 승인 필요 방식에서 동시 승인 처리" do
    # 병렬 승인 결재선 생성 (전체 승인 필요)
    approval_line = @employee.approval_lines.create!(
      name: "병렬 승인 결재선",
      is_active: true,
      approval_line_steps_attributes: {
        "0" => {
          approver_id: @approver1.id,
          step_order: 1,
          role: "approve",
          approval_type: "all_required"
        },
        "1" => {
          approver_id: @approver2.id,
          step_order: 1,
          role: "approve",
          approval_type: "all_required"
        },
        "2" => {
          approver_id: @approver3.id,
          step_order: 1,
          role: "approve",
          approval_type: "all_required"
        }
      }
    )
    
    # 경비 시트와 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 50000,
      description: "동시성 테스트",
      vendor_name: "테스트",
      approval_line: approval_line,
      custom_fields: {}
    )
    
    approval_request = expense_item.approval_request
    
    # 각 승인자가 거의 동시에 승인 시도
    threads = []
    results = []
    
    [@approver1, @approver2, @approver3].each do |approver|
      threads << Thread.new do
        begin
          # 트랜잭션 내에서 처리
          ActiveRecord::Base.transaction do
            ar = ApprovalRequest.find(approval_request.id)
            ar.process_approval(approver, "승인 #{approver.name}")
            results << { approver: approver.name, success: true }
          end
        rescue => e
          results << { approver: approver.name, success: false, error: e.message }
        end
      end
    end
    
    # 모든 스레드 종료 대기
    threads.each(&:join)
    
    # 결과 확인
    successful_approvals = results.select { |r| r[:success] }
    assert_equal 3, successful_approvals.count, "전체 승인 필요 방식에서는 모든 승인이 성공해야 합니다"
    
    # 최종 상태 확인
    approval_request.reload
    assert_equal "approved", approval_request.status
    
    # 승인 이력 확인
    histories = approval_request.approval_histories.where(action: "approve")
    assert_equal 3, histories.count
    assert_equal [@approver1, @approver2, @approver3].map(&:id).sort, 
                 histories.pluck(:approver_id).sort
  end

  test "단일 승인 가능 방식에서 첫 번째 승인만 유효" do
    # 단일 승인 가능 결재선 생성
    approval_line = @employee.approval_lines.create!(
      name: "단일 승인 결재선",
      is_active: true,
      approval_line_steps_attributes: {
        "0" => {
          approver_id: @approver1.id,
          step_order: 1,
          role: "approve",
          approval_type: "single_allowed"
        },
        "1" => {
          approver_id: @approver2.id,
          step_order: 1,
          role: "approve",
          approval_type: "single_allowed"
        }
      }
    )
    
    # 경비 시트와 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 30000,
      description: "단일 승인 테스트",
      vendor_name: "테스트",
      approval_line: approval_line,
      custom_fields: {}
    )
    
    approval_request = expense_item.approval_request
    
    # 동시 승인 시도
    threads = []
    results = []
    
    [@approver1, @approver2].each do |approver|
      threads << Thread.new do
        begin
          # 약간의 지연을 두어 실제 동시 상황 시뮬레이션
          sleep(rand * 0.1)
          
          ActiveRecord::Base.transaction do
            ar = ApprovalRequest.find(approval_request.id)
            ar.process_approval(approver, "승인 #{approver.name}")
            results << { approver: approver.name, success: true }
          end
        rescue => e
          results << { approver: approver.name, success: false, error: e.message }
        end
      end
    end
    
    threads.each(&:join)
    
    # 하나만 성공해야 함
    successful_approvals = results.select { |r| r[:success] }
    assert_equal 1, successful_approvals.count, "단일 승인 가능 방식에서는 하나만 승인 성공"
    
    # 나머지는 실패
    failed_approvals = results.select { |r| !r[:success] }
    assert_equal 1, failed_approvals.count
    # 동시성 상황에 따라 두 가지 에러 가능: "이미 승인되었습니다" 또는 "승인 권한이 없습니다"
    assert failed_approvals.first[:error].match?(/이미 승인되었습니다|승인 권한이 없습니다/), 
           "예상하지 못한 에러: #{failed_approvals.first[:error]}"
    
    # 최종 상태 확인
    approval_request.reload
    assert_equal "approved", approval_request.status
  end

  test "중복 승인 방지 메커니즘" do
    # 단순 승인 결재선 생성
    approval_line = @employee.approval_lines.create!(
      name: "단순 결재선",
      is_active: true,
      approval_line_steps_attributes: {
        "0" => {
          approver_id: @approver1.id,
          step_order: 1,
          role: "approve"
        }
      }
    )
    
    # 경비 시트와 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 20000,
      description: "중복 승인 테스트",
      vendor_name: "테스트",
      approval_line: approval_line,
      custom_fields: {}
    )
    
    approval_request = expense_item.approval_request
    
    # 첫 번째 승인 성공
    approval_request.process_approval(@approver1, "첫 번째 승인")
    
    approval_request.reload
    assert_equal "approved", approval_request.status
    
    # 두 번째 승인 시도 - 실패해야 함
    assert_raises(ArgumentError) do
      approval_request.process_approval(@approver1, "두 번째 승인")
    end
    
    # 승인 이력은 하나만 있어야 함
    histories = approval_request.approval_histories.where(
      approver: @approver1,
      action: "approve"
    )
    assert_equal 1, histories.count
  end

  test "다단계 승인에서 순서 보장" do
    # 2단계 결재선 생성
    approval_line = @employee.approval_lines.create!(
      name: "2단계 결재선",
      is_active: true,
      approval_line_steps_attributes: {
        "0" => {
          approver_id: @approver1.id,
          step_order: 1,
          role: "approve"
        },
        "1" => {
          approver_id: @approver2.id,
          step_order: 2,
          role: "approve"
        }
      }
    )
    
    # 경비 시트와 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 40000,
      description: "순서 보장 테스트",
      vendor_name: "테스트",
      approval_line: approval_line,
      custom_fields: {}
    )
    
    approval_request = expense_item.approval_request
    
    # 2단계 승인자가 먼저 승인 시도 - 실패해야 함
    assert_raises(ArgumentError, "현재 단계가 아닌 승인자는 승인할 수 없습니다") do
      approval_request.process_approval(@approver2, "잘못된 순서")
    end
    
    # 1단계 승인자가 승인
    approval_request.process_approval(@approver1, "1단계 승인")
    
    approval_request.reload
    assert_equal 2, approval_request.current_step
    assert_equal "pending", approval_request.status
    
    # 이제 2단계 승인자가 승인
    approval_request.process_approval(@approver2, "2단계 승인")
    
    approval_request.reload
    assert_equal "approved", approval_request.status
  end

  test "반려 시 동시성 제어" do
    # 병렬 승인 결재선 생성
    approval_line = @employee.approval_lines.create!(
      name: "병렬 반려 테스트",
      is_active: true,
      approval_line_steps_attributes: {
        "0" => {
          approver_id: @approver1.id,
          step_order: 1,
          role: "approve",
          approval_type: "all_required"
        },
        "1" => {
          approver_id: @approver2.id,
          step_order: 1,
          role: "approve",
          approval_type: "all_required"
        }
      }
    )
    
    # 경비 시트와 항목 생성
    expense_sheet = @employee.expense_sheets.create!(
      organization: @organization,
      year: Date.current.year,
      month: Date.current.month,
      status: "draft"
    )
    
    expense_item = expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 60000,
      description: "반려 동시성 테스트",
      vendor_name: "테스트",
      approval_line: approval_line,
      custom_fields: {}
    )
    
    approval_request = expense_item.approval_request
    
    # 한 명은 승인, 한 명은 반려 시도
    threads = []
    results = []
    
    threads << Thread.new do
      begin
        sleep(0.05)  # 약간의 지연
        ActiveRecord::Base.transaction do
          ar = ApprovalRequest.find(approval_request.id)
          ar.process_approval(@approver1, "승인")
          results << { approver: @approver1.name, action: "approve", success: true }
        end
      rescue => e
        results << { approver: @approver1.name, action: "approve", success: false, error: e.message }
      end
    end
    
    threads << Thread.new do
      begin
        ActiveRecord::Base.transaction do
          ar = ApprovalRequest.find(approval_request.id)
          ar.process_rejection(@approver2, "반려")
          results << { approver: @approver2.name, action: "reject", success: true }
        end
      rescue => e
        results << { approver: @approver2.name, action: "reject", success: false, error: e.message }
      end
    end
    
    threads.each(&:join)
    
    # 둘 중 하나만 성공해야 함
    successful_results = results.select { |r| r[:success] }
    assert_equal 1, successful_results.count
    
    # 최종 상태 확인
    approval_request.reload
    if successful_results.first[:action] == "reject"
      assert_equal "rejected", approval_request.status
    else
      # 승인이 먼저 처리된 경우, 여전히 pending (전체 승인 필요)
      assert_equal "pending", approval_request.status
    end
  end
end