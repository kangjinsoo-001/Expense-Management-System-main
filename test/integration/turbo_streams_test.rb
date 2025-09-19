require "test_helper"

class TurboStreamsTest < ActionDispatch::IntegrationTest
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

  test "creates expense item with turbo stream" do
    post login_path, params: { email: @user.email, password: 'password' }
    
    assert_difference '@expense_sheet.expense_items.count', 1 do
      post expense_sheet_expense_items_path(@expense_sheet), 
           params: {
             expense_item: {
               expense_code_id: @expense_code.id,
               cost_center_id: @cost_center.id,
               expense_date: Date.current,
               amount: 50000,
               description: "테스트 경비 항목"
             }
           },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    
    assert_response :success
    assert_match "turbo-stream", response.content_type
    
    # Turbo Stream 응답 검증
    assert_match 'action="append"', response.body
    assert_match 'target="expense_items"', response.body
    assert_match '테스트 경비 항목', response.body
    assert_match '50,000.00 ₩', response.body
  end

  test "updates expense item with turbo stream" do
    post login_path, params: { email: @user.email, password: 'password' }
    
    expense_item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 30000,
      description: "원래 설명"
    )
    
    patch expense_sheet_expense_item_path(@expense_sheet, expense_item),
          params: {
            expense_item: {
              amount: 40000,
              description: "수정된 설명"
            }
          },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_match "turbo-stream", response.content_type
    
    # Turbo Stream 응답 검증
    assert_match 'action="replace"', response.body
    assert_match "target=\"#{dom_id(expense_item)}\"", response.body
    assert_match '수정된 설명', response.body
    assert_match '40,000.00 ₩', response.body
  end

  test "destroys expense item with turbo stream" do
    post login_path, params: { email: @user.email, password: 'password' }
    
    expense_item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 25000,
      description: "삭제할 항목"
    )
    
    assert_difference '@expense_sheet.expense_items.count', -1 do
      delete expense_sheet_expense_item_path(@expense_sheet, expense_item),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    
    assert_response :success
    assert_match "turbo-stream", response.content_type
    
    # Turbo Stream 응답 검증
    assert_match 'action="remove"', response.body
    assert_match "target=\"#{dom_id(expense_item)}\"", response.body
  end

  test "updates total amount after item changes" do
    post login_path, params: { email: @user.email, password: 'password' }
    
    # 초기 총액 확인
    assert_equal 0, @expense_sheet.total_amount
    
    # 항목 추가
    post expense_sheet_expense_items_path(@expense_sheet), 
         params: {
           expense_item: {
             expense_code_id: @expense_code.id,
             cost_center_id: @cost_center.id,
             expense_date: Date.current,
             amount: 100000,
             description: "큰 금액 경비"
           }
         },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    # 총액 업데이트 확인
    assert_match 'target="expense_sheet_total"', response.body
    assert_match '100,000.00 ₩', response.body
  end

  test "handles validation errors without turbo stream" do
    post login_path, params: { email: @user.email, password: 'password' }
    
    # 잘못된 데이터로 생성 시도
    post expense_sheet_expense_items_path(@expense_sheet), 
         params: {
           expense_item: {
             expense_code_id: @expense_code.id,
             cost_center_id: @cost_center.id,
             expense_date: Date.current + 1.day, # 미래 날짜
             amount: -100, # 음수 금액
             description: "잘못된 데이터"
           }
         }
    
    assert_response :unprocessable_entity
    assert_select ".bg-red-50", text: /다음 오류를 수정해주세요/
  end
end