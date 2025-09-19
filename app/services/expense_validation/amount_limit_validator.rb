module ExpenseValidation
  class AmountLimitValidator < BaseValidator
    def initialize(expense_code, expense_item = nil)
      @expense_code = expense_code
      @expense_item = expense_item
    end

    def validate(expense_item)
      return ValidationResult.success unless expense_item.respond_to?(:amount)
      return ValidationResult.success if expense_item.amount.nil?
      
      # 한도가 nil이면 (한도 없음) 검증 통과
      return ValidationResult.success if @expense_code.limit_amount.blank?
      
      # 동적 한도 계산
      calculated_limit = @expense_code.calculate_limit_amount(expense_item)
      
      # 한도 계산이 불가능한 경우 (필드 값이 없는 경우 등)
      return ValidationResult.success if calculated_limit.nil?
      
      if expense_item.amount > calculated_limit
        # 한도 표시 메시지 개선
        limit_display = if @expense_code.has_formula_limit?
          "#{@expense_code.limit_amount_display} = #{format_currency(calculated_limit)}"
        else
          format_currency(calculated_limit)
        end
        
        error = "한도 초과: #{limit_display}"
        ValidationResult.failure(error)
      else
        ValidationResult.success
      end
    end
    
    private
    
    def format_currency(amount)
      return "₩0" if amount.nil? || amount == 0
      
      # 천 단위 구분 쉼표 추가
      formatted = amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      "₩#{formatted}"
    end
  end
end