require "test_helper"

module ExpenseValidation
  class ValidationResultTest < ActiveSupport::TestCase
    test "should create successful result" do
      result = ValidationResult.success
      assert result.valid?
      assert_not result.invalid?
      assert_empty result.errors
    end

    test "should create failure result with errors" do
      errors = ["에러 1", "에러 2"]
      result = ValidationResult.failure(errors)
      assert_not result.valid?
      assert result.invalid?
      assert_equal errors, result.errors
    end

    test "should add error to result" do
      result = ValidationResult.success
      assert result.valid?
      
      result.add_error("새로운 에러")
      assert_not result.valid?
      assert_includes result.errors, "새로운 에러"
    end

    test "should merge results" do
      result1 = ValidationResult.success
      result1.add_error("에러 1")
      
      result2 = ValidationResult.failure(["에러 2", "에러 3"])
      
      result1.merge!(result2)
      assert_not result1.valid?
      assert_equal 3, result1.errors.count
      assert_includes result1.errors, "에러 1"
      assert_includes result1.errors, "에러 2"
      assert_includes result1.errors, "에러 3"
    end

    test "should return error messages as string" do
      result = ValidationResult.failure(["에러 1", "에러 2"])
      assert_equal "에러 1, 에러 2", result.error_messages
    end

    test "should have string representation" do
      success_result = ValidationResult.success
      assert_equal "Valid", success_result.to_s
      
      failure_result = ValidationResult.failure(["에러 1"])
      assert_equal "Invalid: 에러 1", failure_result.to_s
    end
  end
end