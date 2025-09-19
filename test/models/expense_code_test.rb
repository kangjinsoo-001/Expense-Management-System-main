require "test_helper"
require 'ostruct'

class ExpenseCodeTest < ActiveSupport::TestCase
  def setup
    @organization = organizations(:company)
    @expense_code = ExpenseCode.new(
      code: "TRAVEL002",
      name: "국내 출장비",
      description: "국내 출장 관련 경비",
      limit_amount: 500000,
      organization: @organization,
      validation_rules: {
        required_fields: ["출장지", "출장목적"],
        auto_approval_conditions: [
          { "type" => "amount_under", "value" => 100000 },
          { "type" => "within_days", "value" => 7 }
        ]
      }
    )
  end
  
  test "should be valid with valid attributes" do
    assert @expense_code.valid?
  end
  
  test "should require code" do
    @expense_code.code = nil
    assert_not @expense_code.valid?
    assert_includes @expense_code.errors[:code], "는 필수입니다"
  end
  
  test "should require name" do
    @expense_code.name = nil
    assert_not @expense_code.valid?
    assert_includes @expense_code.errors[:name], "은 필수입니다"
  end
  
  test "should enforce unique code" do
    @expense_code.save!
    duplicate = @expense_code.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "는 이미 사용 중입니다"
  end
  
  test "should validate limit_amount is non-negative" do
    @expense_code.limit_amount = -1000
    assert_not @expense_code.valid?
    assert_includes @expense_code.errors[:limit_amount], "는 0 이상이어야 합니다"
  end
  
  test "should allow nil limit_amount" do
    @expense_code.limit_amount = nil
    assert @expense_code.valid?
  end
  
  test "should have active scope" do
    @expense_code.save!
    inactive_code = ExpenseCode.create!(
      code: "INACTIVE001",
      name: "비활성 코드",
      active: false,
      organization: @organization
    )
    
    active_codes = ExpenseCode.active
    assert_includes active_codes, @expense_code
    assert_not_includes active_codes, inactive_code
  end
  
  test "should have with_limit scope" do
    @expense_code.save!
    no_limit_code = ExpenseCode.create!(
      code: "NOLIMIT001",
      name: "한도 없음",
      limit_amount: nil,
      organization: @organization
    )
    
    with_limit_codes = ExpenseCode.with_limit
    assert_includes with_limit_codes, @expense_code
    assert_not_includes with_limit_codes, no_limit_code
  end
  
  test "should access store_accessor fields" do
    assert_equal ["출장지", "출장목적"], @expense_code.required_fields
    assert_equal 2, @expense_code.auto_approval_conditions.length
  end
  
  test "should validate expense item with missing required fields" do
    item = OpenStruct.new(custom_fields: {})
    errors = @expense_code.validate_expense_item(item)
    
    assert_includes errors, "출장지는(은) 필수입니다"
    assert_includes errors, "출장목적는(은) 필수입니다"
  end
  
  test "should validate expense item exceeding limit" do
    item = OpenStruct.new(
      custom_fields: { "출장지" => "서울", "출장목적" => "회의" },
      amount: 600000
    )
    errors = @expense_code.validate_expense_item(item)
    
    assert_includes errors, "한도 초과: 500,000.00원"
  end
  
  test "should check auto approval conditions" do
    # 조건 충족: 금액 10만원 이하, 7일 이내
    item = OpenStruct.new(
      amount: 50000,
      expense_date: Date.current - 3.days,
      receipts: []
    )
    assert @expense_code.auto_approvable?(item)
    
    # 조건 미충족: 금액 초과
    item.amount = 150000
    assert_not @expense_code.auto_approvable?(item)
    
    # 조건 미충족: 기간 초과
    item.amount = 50000
    item.expense_date = Date.current - 10.days
    assert_not @expense_code.auto_approvable?(item)
  end
  
  test "should handle for_organization scope" do
    @expense_code.save!
    
    # 조직 전체 공통 코드
    global_code = ExpenseCode.create!(
      code: "GLOBAL001",
      name: "전체 공통",
      organization: nil
    )
    
    # 다른 조직 코드
    other_org = organizations(:one)
    other_code = ExpenseCode.create!(
      code: "OTHER001",
      name: "다른 조직",
      organization: other_org
    )
    
    org_codes = ExpenseCode.for_organization(@organization)
    assert_includes org_codes, @expense_code
    assert_includes org_codes, global_code
    assert_not_includes org_codes, other_code
  end
end
