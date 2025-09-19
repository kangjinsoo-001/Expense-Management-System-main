require "test_helper"

class ExpenseValidationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:employee_one)
    @expense_sheet = ExpenseSheet.create!(
      user: @user,
      organization: @user.organization,
      year: Date.current.year,
      month: Date.current.month
    )
    @expense_code = expense_codes(:one)
    @cost_center = cost_centers(:one)
  end

  test "validates amount field in real time" do
    post login_path, params: { email: @user.email, password: 'password' }
    
    get new_expense_sheet_expense_item_path(@expense_sheet)
    assert_response :success
    
    # 폼에 실시간 검증 타겟이 있는지 확인
    assert_select "[data-expense-item-form-target='amount']"
    assert_select "[data-expense-item-form-target='expenseDate']"
    assert_select "[data-expense-item-form-target='description']"
    assert_select "[data-expense-item-form-target='validationErrors']"
  end

  test "shows custom fields based on expense code selection" do
    post login_path, params: { email: @user.email, password: 'password' }
    
    get new_expense_sheet_expense_item_path(@expense_sheet)
    assert_response :success
    
    # 경비 코드 선택 시 커스텀 필드가 표시되는지 확인
    assert_select "[data-expense-item-form-target='customFields']"
    assert_select "[data-expense-item-form-target='expenseCode']"
  end

  test "displays validation errors when saving invalid expense item" do
    post login_path, params: { email: @user.email, password: 'password' }
    
    # 잘못된 데이터로 경비 항목 생성 시도
    post expense_sheet_expense_items_path(@expense_sheet), params: {
      expense_item: {
        expense_code_id: @expense_code.id,
        cost_center_id: @cost_center.id,
        expense_date: Date.current + 1.day, # 미래 날짜
        amount: -100, # 음수 금액
        description: "짧음" # 너무 짧은 설명
      }
    }
    
    assert_response :unprocessable_entity
    assert_select ".bg-red-50" # 에러 메시지 컨테이너
  end

  test "expense date must be within expense sheet period" do
    post login_path, params: { email: @user.email, password: 'password' }
    
    # 다른 월의 날짜로 경비 항목 생성 시도
    post expense_sheet_expense_items_path(@expense_sheet), params: {
      expense_item: {
        expense_code_id: @expense_code.id,
        cost_center_id: @cost_center.id,
        expense_date: Date.current.prev_month,
        amount: 10000,
        description: "이전 달 경비"
      }
    }
    
    # 경비 항목이 생성되지 않아야 함
    assert_equal 0, @expense_sheet.expense_items.count
  end

  test "form includes year and month data attributes" do
    post login_path, params: { email: @user.email, password: 'password' }
    
    get new_expense_sheet_expense_item_path(@expense_sheet)
    assert_response :success
    
    # 폼에 년/월 데이터 속성이 있는지 확인
    assert_select "form[data-sheet-year='#{@expense_sheet.year}']"
    assert_select "form[data-sheet-month='#{@expense_sheet.month}']"
  end
end