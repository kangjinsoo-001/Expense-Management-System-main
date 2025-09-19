require "test_helper"

class ExpenseSheetFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:employee_one)
    @expense_code = expense_codes(:one)
    @cost_center = cost_centers(:one)
  end

  test "user can create expense sheet and add items" do
    # 로그인
    post login_path, params: { email: @user.email, password: 'password' }
    follow_redirect!
    assert_response :success
    
    # 경비 시트 목록 페이지 방문
    get expense_sheets_path
    assert_response :success
    assert_select "h1", "경비 시트"
    
    # 새 경비 시트 생성 페이지
    get new_expense_sheet_path
    assert_response :success
    assert_select "h3", "새 경비 시트 생성"
    
    # 경비 시트 생성
    post expense_sheets_path, params: { 
      expense_sheet: { 
        year: Date.current.year, 
        month: Date.current.month,
        remarks: "테스트 경비 시트"
      } 
    }
    expense_sheet = ExpenseSheet.last
    assert_redirected_to expense_sheet_path(expense_sheet)
    follow_redirect!
    
    # 경비 시트 상세 페이지
    assert_response :success
    assert_select "h3", /#{Date.current.year}년 #{Date.current.month}월 경비 시트/
    assert_select "span", "작성중"
    
    # 경비 항목 추가 페이지
    get new_expense_sheet_expense_item_path(expense_sheet)
    assert_response :success
    assert_select "h3", "새 경비 항목 추가"
    
    # 경비 항목 추가
    post expense_sheet_expense_items_path(expense_sheet), params: {
      expense_item: {
        expense_code_id: @expense_code.id,
        cost_center_id: @cost_center.id,
        expense_date: Date.current,
        amount: 30000,
        description: "테스트 경비 항목",
        vendor_name: "테스트 거래처",
        receipt_number: "REC001"
      }
    }
    
    assert_redirected_to expense_sheet_path(expense_sheet)
    follow_redirect!
    
    # 경비 항목이 표시되는지 확인
    assert_response :success
    assert_select "td", @expense_code.name_with_code
    assert_select "td", "₩30,000"
  end

  test "expense item form shows dynamic fields based on expense code" do
    post login_path, params: { email: @user.email, password: 'password' }
    expense_sheet = ExpenseSheet.create!(
      user: @user,
      organization: @user.organization,
      year: Date.current.year,
      month: Date.current.month
    )
    
    get new_expense_sheet_expense_item_path(expense_sheet)
    assert_response :success
    
    # JavaScript 컨트롤러가 포함되어 있는지 확인
    assert_select "[data-controller='expense-item-form']"
    assert_select "[data-expense-item-form-target='expenseCode']"
    assert_select "[data-expense-item-form-target='customFields']"
  end
end