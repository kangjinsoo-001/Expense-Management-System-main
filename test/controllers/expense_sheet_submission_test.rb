require "test_helper"

class ExpenseSheetSubmissionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:employee)
    @expense_sheet = expense_sheets(:draft_sheet)
    @expense_code = expense_codes(:transportation)
    @cost_center = cost_centers(:one)
    
    # 로그인
    post login_path, params: { email: @user.email, password: "password" }
  end

  test "경비 시트 제출 성공" do
    # 유효한 경비 항목 추가
    @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "교통비",
      is_valid: true,
      custom_fields: {}
    )
    
    assert_difference("AuditLog.count", 1) do
      post submit_expense_sheet_path(@expense_sheet)
    end
    
    assert_redirected_to expense_sheet_path(@expense_sheet)
    follow_redirect!
    assert_select ".bg-yellow-100", text: "제출됨"
    
    @expense_sheet.reload
    assert_equal "submitted", @expense_sheet.status
    assert_not_nil @expense_sheet.submitted_at
  end

  test "검증되지 않은 항목이 있으면 제출 실패" do
    # 무효한 경비 항목 추가
    item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "교통비",
      custom_fields: {}
    )
    item.update_column(:is_valid, false)
    
    assert_no_difference("AuditLog.count") do
      post submit_expense_sheet_path(@expense_sheet)
    end
    
    assert_redirected_to expense_sheet_path(@expense_sheet)
    follow_redirect!
    assert_match "검증되지 않은 경비 항목이", flash[:alert]
    
    @expense_sheet.reload
    assert_equal "draft", @expense_sheet.status
  end

  test "경비 항목이 없으면 제출 실패" do
    assert_no_difference("AuditLog.count") do
      post submit_expense_sheet_path(@expense_sheet)
    end
    
    assert_redirected_to expense_sheet_path(@expense_sheet)
    follow_redirect!
    assert_match "경비 항목이 없습니다", flash[:alert]
  end

  test "제출된 시트는 수정 불가" do
    # 시트를 제출 상태로 변경
    @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "교통비",
      is_valid: true,
      custom_fields: {}
    )
    @expense_sheet.submit!(@user)
    
    # 경비 항목 추가 시도
    get new_expense_sheet_expense_item_path(@expense_sheet)
    assert_redirected_to expense_sheet_path(@expense_sheet)
    assert_equal "수정할 수 없는 상태입니다.", flash[:alert]
    
    # 경비 항목 수정 시도
    item = @expense_sheet.expense_items.first
    get edit_expense_sheet_expense_item_path(@expense_sheet, item)
    assert_redirected_to expense_sheet_path(@expense_sheet)
    assert_equal "수정할 수 없는 상태입니다.", flash[:alert]
  end

  test "검증 API 동작 확인" do
    # 경비 항목 추가
    @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "교통비",
      is_valid: true,
      custom_fields: {}
    )
    
    item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 5000,
      description: "교통비2",
      custom_fields: {}
    )
    item.update_column(:is_valid, false)
    
    get validate_items_expense_sheet_path(@expense_sheet), as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal 1, json_response["valid_count"]
    assert_equal 1, json_response["invalid_count"]
    assert_equal 2, json_response["total_count"]
    assert_not json_response["all_valid"]
  end
end