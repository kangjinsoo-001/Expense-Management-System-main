require "test_helper"
require 'ostruct'

module ExpenseValidation
  class AmountLimitValidatorTest < ActiveSupport::TestCase
    def setup
      @limit_amount = 500000
      @validator = AmountLimitValidator.new(@limit_amount)
    end

    test "should pass validation when amount is under limit" do
      item = OpenStruct.new(amount: 300000)
      
      result = @validator.validate(item)
      assert result.valid?
      assert_empty result.errors
    end

    test "should pass validation when amount equals limit" do
      item = OpenStruct.new(amount: 500000)
      
      result = @validator.validate(item)
      assert result.valid?
      assert_empty result.errors
    end

    test "should fail validation when amount exceeds limit" do
      item = OpenStruct.new(amount: 600000)
      
      result = @validator.validate(item)
      assert_not result.valid?
      assert_equal 1, result.errors.count
      assert_includes result.errors.first, "한도 초과: 500,000.00원"
    end

    test "should handle nil amount" do
      item = OpenStruct.new(amount: nil)
      
      result = @validator.validate(item)
      assert result.valid?
    end

    test "should handle item without amount method" do
      item = OpenStruct.new(custom_fields: {})
      
      result = @validator.validate(item)
      assert result.valid?
    end

    test "should format currency correctly" do
      validator = AmountLimitValidator.new(1234567)
      item = OpenStruct.new(amount: 2000000)
      
      result = validator.validate(item)
      assert_not result.valid?
      assert_includes result.errors.first, "1,234,567.00원"
    end
  end
end