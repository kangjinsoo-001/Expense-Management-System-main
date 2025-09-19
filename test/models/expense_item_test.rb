require "test_helper"

class ExpenseItemTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @organization = organizations(:one)
    @expense_sheet = ExpenseSheet.create!(
      user: @user,
      organization: @organization,
      year: Date.current.year,
      month: Date.current.month,
      status: 'draft'
    )
    @expense_code = expense_codes(:one)
    @cost_center = cost_centers(:one)
  end

  test "유효한 경비 항목 생성" do
    expense_item = @expense_sheet.expense_items.build(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트 경비"
    )
    
    assert expense_item.valid?
  end

  test "필수 필드 검증" do
    expense_item = @expense_sheet.expense_items.build
    
    assert_not expense_item.valid?
    assert_not_nil expense_item.errors[:expense_date]
    assert_not_nil expense_item.errors[:amount]
    assert_not_nil expense_item.errors[:description]
    assert_not_nil expense_item.errors[:expense_code]
    assert_not_nil expense_item.errors[:cost_center]
  end

  test "금액 양수 검증" do
    expense_item = @expense_sheet.expense_items.build(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: -1000,
      description: "테스트 경비"
    )
    
    assert_not expense_item.valid?
    assert_not_nil expense_item.errors[:amount]
  end

  test "경비 날짜가 시트 기간과 일치해야 함" do
    expense_item = @expense_sheet.expense_items.build(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current - 2.months,  # 다른 월
      amount: 10000,
      description: "테스트 경비"
    )
    
    assert_not expense_item.valid?
    assert_includes expense_item.errors[:expense_date], "경비 시트 기간(#{@expense_sheet.period})과 일치해야 합니다"
  end

  test "금액 포맷팅" do
    expense_item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 50000,  # 한도 내 금액으로 변경
      description: "테스트 경비"
    )
    
    assert_equal "₩50,000", expense_item.formatted_amount
  end

  test "검증 상태 표시" do
    expense_item = @expense_sheet.expense_items.build(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트 경비"
    )
    
    # is_valid 직접 설정
    expense_item.is_valid = true
    expense_item.save!(validate: false)
    assert_equal "유효", expense_item.validation_status
    
    expense_item.is_valid = false
    expense_item.save!(validate: false)
    assert_equal "검증 필요", expense_item.validation_status
  end

  test "편집 가능 여부는 시트 상태에 따름" do
    expense_item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트 경비"
    )
    
    # draft 상태에서는 편집 가능
    assert expense_item.editable?
    
    # submitted 상태에서는 편집 불가
    @expense_sheet.update!(status: 'submitted')
    assert_not expense_item.editable?
    
    # rejected 상태에서는 다시 편집 가능
    @expense_sheet.update!(status: 'rejected')
    assert expense_item.editable?
  end

  test "경비 시트 총액 자동 업데이트" do
    assert_equal 0, @expense_sheet.total_amount
    
    # 항목 추가
    expense_item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트 경비"
    )
    
    @expense_sheet.reload
    assert_equal 10000, @expense_sheet.total_amount
    
    # 항목 수정
    expense_item.update!(amount: 20000)
    @expense_sheet.reload
    assert_equal 20000, @expense_sheet.total_amount
    
    # 항목 삭제
    expense_item.destroy
    @expense_sheet.reload
    assert_equal 0, @expense_sheet.total_amount
  end

  test "스코프 테스트" do
    # 유효/무효 항목
    valid_item = @expense_sheet.expense_items.build(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "유효한 경비"
    )
    valid_item.is_valid = true
    valid_item.save!(validate: false)
    
    invalid_item = @expense_sheet.expense_items.build(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 20000,
      description: "무효한 경비"
    )
    invalid_item.is_valid = false
    invalid_item.save!(validate: false)
    
    assert_includes ExpenseItem.valid, valid_item
    assert_not_includes ExpenseItem.valid, invalid_item
    
    assert_includes ExpenseItem.invalid, invalid_item
    assert_not_includes ExpenseItem.invalid, valid_item
    
    # 날짜 범위
    start_date = Date.current.beginning_of_month
    end_date = Date.current.end_of_month
    date_range_items = ExpenseItem.by_date_range(start_date, end_date)
    
    assert_includes date_range_items, valid_item
    assert_includes date_range_items, invalid_item
    
    # 경비 코드별
    code_items = ExpenseItem.by_expense_code(@expense_code.id)
    assert_includes code_items, valid_item
    
    # 코스트 센터별
    center_items = ExpenseItem.by_cost_center(@cost_center.id)
    assert_includes center_items, valid_item
  end

  test "커스텀 필드 저장 및 조회" do
    expense_item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      cost_center: @cost_center,
      expense_date: Date.current,
      amount: 10000,
      description: "테스트 경비",
      custom_fields: {
        "attendees" => "김철수, 이영희",
        "purpose" => "프로젝트 회의"
      }
    )
    
    expense_item.reload
    assert_equal "김철수, 이영희", expense_item.custom_fields["attendees"]
    assert_equal "프로젝트 회의", expense_item.custom_fields["purpose"]
  end
end