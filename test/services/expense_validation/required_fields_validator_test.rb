require "test_helper"
require 'ostruct'

module ExpenseValidation
  class RequiredFieldsValidatorTest < ActiveSupport::TestCase
    def setup
      @required_fields = ["출장지", "출장목적"]
      @validator = RequiredFieldsValidator.new(@required_fields)
    end

    test "should pass validation when all required fields are present" do
      item = OpenStruct.new(
        custom_fields: {
          "출장지" => "서울",
          "출장목적" => "회의 참석"
        }
      )
      
      result = @validator.validate(item)
      assert result.valid?
      assert_empty result.errors
    end

    test "should fail validation when required fields are missing" do
      item = OpenStruct.new(custom_fields: {})
      
      result = @validator.validate(item)
      assert_not result.valid?
      assert_equal 2, result.errors.count
      assert_includes result.errors, "출장지는(은) 필수입니다"
      assert_includes result.errors, "출장목적는(은) 필수입니다"
    end

    test "should fail validation when required field is empty string" do
      item = OpenStruct.new(
        custom_fields: {
          "출장지" => "   ",
          "출장목적" => "회의"
        }
      )
      
      result = @validator.validate(item)
      assert_not result.valid?
      assert_includes result.errors, "출장지는(은) 필수입니다"
    end

    test "should handle nil custom_fields" do
      item = OpenStruct.new(custom_fields: nil)
      
      result = @validator.validate(item)
      assert_not result.valid?
      assert_equal 2, result.errors.count
    end

    test "should handle item without custom_fields method" do
      item = OpenStruct.new(amount: 10000)
      
      result = @validator.validate(item)
      assert_not result.valid?
      assert_equal 2, result.errors.count
    end

    test "should work with single required field" do
      validator = RequiredFieldsValidator.new("참석자")
      item = OpenStruct.new(custom_fields: { "참석자" => "김철수" })
      
      result = validator.validate(item)
      assert result.valid?
    end
  end
end