module ExpenseValidation
  class RequiredFieldsValidator < BaseValidator
    def initialize(required_fields)
      @required_fields = required_fields
    end

    def validate(expense_item)
      errors = []
      
      if @required_fields.is_a?(Hash)
        # 새로운 해시 구조
        @required_fields.each do |field_key, field_config|
          if field_config['required'] != false && field_value_blank?(expense_item, field_key)
            label = field_config['label'] || field_key
            errors << "#{label}는(은) 필수입니다"
          end
        end
      else
        # 이전 배열 구조 호환성
        Array(@required_fields).each do |field|
          if field_value_blank?(expense_item, field)
            errors << "#{field}는(은) 필수입니다"
          end
        end
      end
      
      errors.empty? ? ValidationResult.success : ValidationResult.failure(errors)
    end

    private

    def field_value_blank?(expense_item, field)
      return true unless expense_item.respond_to?(:custom_fields)
      
      value = expense_item.custom_fields&.dig(field)
      value.nil? || value.to_s.strip.empty?
    end
  end
end