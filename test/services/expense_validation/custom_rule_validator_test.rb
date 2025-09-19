require "test_helper"
require 'ostruct'

module ExpenseValidation
  class CustomRuleValidatorTest < ActiveSupport::TestCase
    test "should validate equals operator" do
      rules = [{ 'field' => '프로젝트', 'operator' => 'equals', 'value' => 'A프로젝트' }]
      validator = CustomRuleValidator.new(rules)
      
      valid_item = OpenStruct.new(custom_fields: { '프로젝트' => 'A프로젝트' })
      assert validator.validate(valid_item).valid?
      
      invalid_item = OpenStruct.new(custom_fields: { '프로젝트' => 'B프로젝트' })
      result = validator.validate(invalid_item)
      assert_not result.valid?
      assert_includes result.errors.first, "A프로젝트이어야 합니다"
    end

    test "should validate not_equals operator" do
      rules = [{ 'field' => '상태', 'operator' => 'not_equals', 'value' => '취소' }]
      validator = CustomRuleValidator.new(rules)
      
      valid_item = OpenStruct.new(custom_fields: { '상태' => '진행중' })
      assert validator.validate(valid_item).valid?
      
      invalid_item = OpenStruct.new(custom_fields: { '상태' => '취소' })
      assert_not validator.validate(invalid_item).valid?
    end

    test "should validate contains operator" do
      rules = [{ 'field' => '설명', 'operator' => 'contains', 'value' => '출장' }]
      validator = CustomRuleValidator.new(rules)
      
      valid_item = OpenStruct.new(custom_fields: { '설명' => '서울 출장 관련 경비' })
      assert validator.validate(valid_item).valid?
      
      invalid_item = OpenStruct.new(custom_fields: { '설명' => '사무용품 구매' })
      assert_not validator.validate(invalid_item).valid?
    end

    test "should validate numeric comparison operators" do
      rules = [
        { 'field' => '인원수', 'operator' => 'greater_than', 'value' => '5' },
        { 'field' => '일수', 'operator' => 'less_than_or_equal', 'value' => '3' }
      ]
      validator = CustomRuleValidator.new(rules)
      
      valid_item = OpenStruct.new(custom_fields: { '인원수' => '10', '일수' => '2' })
      assert validator.validate(valid_item).valid?
      
      invalid_item = OpenStruct.new(custom_fields: { '인원수' => '3', '일수' => '5' })
      result = validator.validate(invalid_item)
      assert_not result.valid?
      assert_equal 2, result.errors.count
    end

    test "should validate regex operator" do
      rules = [{ 'field' => '전화번호', 'operator' => 'matches_regex', 'value' => '^\d{2,3}-\d{3,4}-\d{4}$' }]
      validator = CustomRuleValidator.new(rules)
      
      valid_item = OpenStruct.new(custom_fields: { '전화번호' => '02-1234-5678' })
      assert validator.validate(valid_item).valid?
      
      invalid_item = OpenStruct.new(custom_fields: { '전화번호' => '12345' })
      assert_not validator.validate(invalid_item).valid?
    end

    test "should validate present operator" do
      rules = [{ 'field' => '승인번호', 'operator' => 'present' }]
      validator = CustomRuleValidator.new(rules)
      
      valid_item = OpenStruct.new(custom_fields: { '승인번호' => 'APP123' })
      assert validator.validate(valid_item).valid?
      
      invalid_item = OpenStruct.new(custom_fields: { '승인번호' => '   ' })
      assert_not validator.validate(invalid_item).valid?
    end

    test "should use custom error message if provided" do
      rules = [{
        'field' => '금액',
        'operator' => 'greater_than',
        'value' => '10000',
        'message' => '최소 금액은 10,000원입니다'
      }]
      validator = CustomRuleValidator.new(rules)
      
      invalid_item = OpenStruct.new(custom_fields: { '금액' => '5000' })
      result = validator.validate(invalid_item)
      assert_not result.valid?
      assert_equal "최소 금액은 10,000원입니다", result.errors.first
    end

    test "should handle multiple rules" do
      rules = [
        { 'field' => '프로젝트', 'operator' => 'present' },
        { 'field' => '금액', 'operator' => 'greater_than', 'value' => '0' },
        { 'field' => '상태', 'operator' => 'not_equals', 'value' => '취소' }
      ]
      validator = CustomRuleValidator.new(rules)
      
      valid_item = OpenStruct.new(custom_fields: {
        '프로젝트' => 'A프로젝트',
        '금액' => '50000',
        '상태' => '승인'
      })
      assert validator.validate(valid_item).valid?
    end

    test "should handle missing custom_fields" do
      rules = [{ 'field' => '테스트', 'operator' => 'present' }]
      validator = CustomRuleValidator.new(rules)
      
      item = OpenStruct.new(amount: 10000)
      result = validator.validate(item)
      assert_not result.valid?
      assert_includes result.errors.first, "필수입니다"
    end
  end
end