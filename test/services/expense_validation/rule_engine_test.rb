require "test_helper"
require 'ostruct'

module ExpenseValidation
  class RuleEngineTest < ActiveSupport::TestCase
    def setup
      @expense_code = expense_codes(:travel_expense)
      @expense_code.validation_rules = {
        "required_fields" => ["출장지", "출장목적"],
        "auto_approval_conditions" => [
          { "type" => "amount_under", "value" => 100000 },
          { "type" => "within_days", "value" => 7 }
        ],
        "custom_validators" => [
          { "field" => "인원수", "operator" => "greater_than", "value" => "0" }
        ]
      }
      @expense_code.limit_amount = 500000
      @expense_code.save!
      @engine = RuleEngine.new(@expense_code)
    end

    test "should validate all rules" do
      # 모든 규칙을 통과하는 경우
      valid_item = OpenStruct.new(
        amount: 50000,
        expense_date: Date.current - 3.days,
        custom_fields: {
          "출장지" => "서울",
          "출장목적" => "회의",
          "인원수" => "5"
        },
        receipts: []
      )
      
      result = @engine.validate(valid_item)
      assert result.valid?
      assert_empty result.errors
    end

    test "should collect all validation errors" do
      # 여러 검증 실패
      invalid_item = OpenStruct.new(
        amount: 600000,  # 한도 초과
        custom_fields: {
          "출장지" => "",  # 필수 필드 누락
          "인원수" => "0"  # 커스텀 규칙 위반
        }
      )
      
      result = @engine.validate(invalid_item)
      assert_not result.valid?
      assert result.errors.count >= 3
      
      # 각 유형의 에러가 포함되어 있는지 확인
      assert result.errors.any? { |e| e.include?("필수") }
      assert result.errors.any? { |e| e.include?("한도 초과") }
      assert result.errors.any? { |e| e.include?("커야 합니다") }
    end

    test "should check auto approval conditions" do
      # 자동 승인 조건 충족
      approvable_item = OpenStruct.new(
        amount: 80000,
        expense_date: Date.current - 3.days,
        receipts: []
      )
      
      assert @engine.auto_approvable?(approvable_item)
      
      # 금액 조건 미충족
      high_amount_item = OpenStruct.new(
        amount: 150000,
        expense_date: Date.current - 3.days,
        receipts: []
      )
      
      assert_not @engine.auto_approvable?(high_amount_item)
      
      # 날짜 조건 미충족
      old_date_item = OpenStruct.new(
        amount: 80000,
        expense_date: Date.current - 10.days,
        receipts: []
      )
      
      assert_not @engine.auto_approvable?(old_date_item)
    end

    test "should handle within_limit condition" do
      @expense_code.validation_rules["auto_approval_conditions"] = [
        { "type" => "within_limit" }
      ]
      @expense_code.save!
      engine = RuleEngine.new(@expense_code)
      
      within_limit_item = OpenStruct.new(amount: 400000)
      assert engine.auto_approvable?(within_limit_item)
      
      over_limit_item = OpenStruct.new(amount: 600000)
      assert_not engine.auto_approvable?(over_limit_item)
    end

    test "should handle receipt_attached condition" do
      @expense_code.validation_rules["auto_approval_conditions"] = [
        { "type" => "receipt_attached" }
      ]
      @expense_code.save!
      engine = RuleEngine.new(@expense_code)
      
      with_receipt_item = OpenStruct.new(receipts: [1, 2])
      assert engine.auto_approvable?(with_receipt_item)
      
      without_receipt_item = OpenStruct.new(receipts: [])
      assert_not engine.auto_approvable?(without_receipt_item)
    end

    test "should handle custom field conditions" do
      @expense_code.validation_rules["auto_approval_conditions"] = [
        { "type" => "custom_field_equals", "field" => "프로젝트", "value" => "A프로젝트" },
        { "type" => "custom_field_present", "field" => "승인번호" }
      ]
      @expense_code.save!
      engine = RuleEngine.new(@expense_code)
      
      valid_item = OpenStruct.new(
        custom_fields: {
          "프로젝트" => "A프로젝트",
          "승인번호" => "APP123"
        }
      )
      assert engine.auto_approvable?(valid_item)
      
      invalid_item = OpenStruct.new(
        custom_fields: {
          "프로젝트" => "B프로젝트",
          "승인번호" => "APP123"
        }
      )
      assert_not engine.auto_approvable?(invalid_item)
    end

    test "should handle expense code without rules" do
      empty_code = ExpenseCode.new(
        code: "EMPTY",
        name: "규칙 없음"
      )
      engine = RuleEngine.new(empty_code)
      
      item = OpenStruct.new(amount: 10000)
      result = engine.validate(item)
      assert result.valid?
      assert_empty result.errors
      
      assert_not engine.auto_approvable?(item)
    end

    test "should handle validation errors gracefully" do
      @expense_code.validation_rules["auto_approval_conditions"] = [
        { "type" => "unknown_type" }
      ]
      @expense_code.save!
      engine = RuleEngine.new(@expense_code)
      
      item = OpenStruct.new(amount: 10000)
      assert_not engine.auto_approvable?(item)
    end
  end
end