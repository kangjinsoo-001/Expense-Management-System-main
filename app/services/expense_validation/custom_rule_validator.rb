module ExpenseValidation
  class CustomRuleValidator < BaseValidator
    def initialize(custom_validators)
      @custom_validators = Array(custom_validators)
    end

    def validate(expense_item)
      errors = []
      
      @custom_validators.each do |rule|
        unless evaluate_rule(rule, expense_item)
          errors << format_error_message(rule)
        end
      end
      
      errors.empty? ? ValidationResult.success : ValidationResult.failure(errors)
    end

    private

    def evaluate_rule(rule, expense_item)
      field = rule['field']
      operator = rule['operator']
      expected_value = rule['value']
      
      return false unless expense_item.respond_to?(:custom_fields)
      
      actual_value = expense_item.custom_fields&.dig(field)
      
      case operator
      when 'equals', '=='
        actual_value.to_s == expected_value.to_s
      when 'not_equals', '!='
        actual_value.to_s != expected_value.to_s
      when 'contains'
        actual_value.to_s.include?(expected_value.to_s)
      when 'not_contains'
        !actual_value.to_s.include?(expected_value.to_s)
      when 'greater_than', '>'
        to_number(actual_value) > to_number(expected_value)
      when 'less_than', '<'
        to_number(actual_value) < to_number(expected_value)
      when 'greater_than_or_equal', '>='
        to_number(actual_value) >= to_number(expected_value)
      when 'less_than_or_equal', '<='
        to_number(actual_value) <= to_number(expected_value)
      when 'matches_regex'
        actual_value.to_s.match?(Regexp.new(expected_value))
      when 'present'
        !actual_value.to_s.strip.empty?
      when 'blank'
        actual_value.to_s.strip.empty?
      else
        false
      end
    rescue StandardError
      false
    end

    def to_number(value)
      return 0 if value.nil?
      value.to_s.gsub(/[^\d.-]/, '').to_f
    end

    def format_error_message(rule)
      field = rule['field']
      operator = rule['operator']
      value = rule['value']
      message = rule['message']
      
      return message if message.present?
      
      case operator
      when 'equals', '=='
        "#{field}는(은) #{value}이어야 합니다"
      when 'not_equals', '!='
        "#{field}는(은) #{value}이면 안 됩니다"
      when 'contains'
        "#{field}에 #{value}가 포함되어야 합니다"
      when 'not_contains'
        "#{field}에 #{value}가 포함되면 안 됩니다"
      when 'greater_than', '>'
        "#{field}는(은) #{value}보다 커야 합니다"
      when 'less_than', '<'
        "#{field}는(은) #{value}보다 작아야 합니다"
      when 'greater_than_or_equal', '>='
        "#{field}는(은) #{value} 이상이어야 합니다"
      when 'less_than_or_equal', '<='
        "#{field}는(은) #{value} 이하여야 합니다"
      when 'matches_regex'
        "#{field}의 형식이 올바르지 않습니다"
      when 'present'
        "#{field}는(은) 필수입니다"
      when 'blank'
        "#{field}는(은) 비어있어야 합니다"
      else
        "#{field} 검증 실패"
      end
    end
  end
end