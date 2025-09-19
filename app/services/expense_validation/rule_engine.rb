module ExpenseValidation
  class RuleEngine
    def initialize(expense_code)
      @expense_code = expense_code
      @validators = build_validators
    end

    def validate(expense_item)
      result = ValidationResult.success
      
      @validators.each do |validator|
        validator_result = validator.validate(expense_item)
        result.merge!(validator_result)
      end
      
      result
    end

    def auto_approvable?(expense_item)
      return false unless @expense_code.auto_approval_conditions.present?
      
      @expense_code.auto_approval_conditions.all? do |condition|
        evaluate_condition(condition, expense_item)
      end
    end

    private

    def build_validators
      validators = []
      
      # 필수 필드 검증
      if @expense_code.required_fields.present?
        validators << RequiredFieldsValidator.new(@expense_code.required_fields)
      end
      
      # 금액 한도 검증
      if @expense_code.limit_amount.present?
        validators << AmountLimitValidator.new(@expense_code)
      end
      
      # 커스텀 검증 규칙
      if @expense_code.custom_validators.present?
        validators << CustomRuleValidator.new(@expense_code.custom_validators)
      end
      
      validators
    end

    def evaluate_condition(condition, expense_item)
      case condition['type']
      when 'amount_under'
        return false unless expense_item.respond_to?(:amount)
        expense_item.amount <= condition['value'].to_f
      when 'within_limit'
        return false unless expense_item.respond_to?(:amount)
        return false unless @expense_code.limit_amount.present?
        
        calculated_limit = @expense_code.calculate_limit_amount(expense_item)
        return false if calculated_limit.nil?
        
        expense_item.amount <= calculated_limit
      when 'receipt_attached'
        return false unless expense_item.respond_to?(:receipts)
        expense_item.receipts.any?
      when 'within_days'
        return false unless expense_item.respond_to?(:expense_date)
        return false if expense_item.expense_date.nil?
        (Date.current - expense_item.expense_date).to_i <= condition['value'].to_i
      when 'custom_field_equals'
        field = condition['field']
        value = condition['value']
        return false unless expense_item.respond_to?(:custom_fields)
        expense_item.custom_fields&.dig(field).to_s == value.to_s
      when 'custom_field_present'
        field = condition['field']
        return false unless expense_item.respond_to?(:custom_fields)
        !expense_item.custom_fields&.dig(field).to_s.strip.empty?
      else
        false
      end
    rescue StandardError
      false
    end
  end
end