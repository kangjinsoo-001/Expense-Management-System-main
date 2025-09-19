require 'test_helper'

class ExpenseCodeApprovalRuleTest < ActiveSupport::TestCase
  setup do
    @admin = users(:one)
    @expense_code = expense_codes(:one)
    @approver_group = approver_groups(:one)
    @rule = ExpenseCodeApprovalRule.create!(
      expense_code: @expense_code,
      approver_group: @approver_group,
      condition: "#금액 > 300000",
      order: 1,
      is_active: true
    )
  end
  
  test "조건식 평가 - 금액 기준" do
    # ExpenseItem 생성
    item = ExpenseItem.new(
      expense_sheet: expense_sheets(:one),
      expense_code: @expense_code,
      amount: 500000,
      expense_date: Date.current
    )
    
    # 50만원 > 30만원이므로 true
    assert @rule.evaluate(item)
    
    # 20만원인 경우
    item.amount = 200000
    assert_not @rule.evaluate(item)
  end
  
  test "조건식 평가 - 커스텀 필드" do
    rule = ExpenseCodeApprovalRule.create!(
      expense_code: @expense_code,
      approver_group: @approver_group,
      condition: "#참석인원 > 10",
      order: 2,
      is_active: true
    )
    
    item = ExpenseItem.new(
      expense_sheet: expense_sheets(:one),
      expense_code: @expense_code,
      amount: 100000,
      expense_date: Date.current,
      custom_fields: { "참석인원" => "15" }
    )
    
    # 15명 > 10명이므로 true
    assert rule.evaluate(item)
    
    # 5명인 경우
    item.custom_fields["참석인원"] = "5"
    assert_not rule.evaluate(item)
  end
  
  test "빈 조건식은 항상 true" do
    rule = ExpenseCodeApprovalRule.create!(
      expense_code: @expense_code,
      approver_group: @approver_group,
      condition: "",
      order: 3,
      is_active: true
    )
    
    item = ExpenseItem.new(amount: 100)
    assert rule.evaluate(item)
  end
  
  test "잘못된 조건식은 false" do
    rule = ExpenseCodeApprovalRule.create!(
      expense_code: @expense_code,
      approver_group: @approver_group,
      condition: "invalid condition",
      order: 4,
      is_active: true
    )
    
    item = ExpenseItem.new(amount: 100)
    assert_not rule.evaluate(item)
  end
end