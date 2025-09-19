module ExpenseValidation
  class ValidationResult
    attr_reader :errors

    def initialize(valid, errors = [])
      @valid = valid
      @errors = Array(errors)
    end

    def valid?
      @valid
    end

    def invalid?
      !@valid
    end

    def add_error(error)
      @errors << error
      @valid = false
    end

    def merge!(other_result)
      @errors.concat(other_result.errors)
      @valid &&= other_result.valid?
      self
    end

    def error_messages
      @errors.join(", ")
    end

    def to_s
      valid? ? "Valid" : "Invalid: #{error_messages}"
    end

    class << self
      def success
        new(true)
      end

      def failure(errors)
        new(false, errors)
      end
    end
  end
end