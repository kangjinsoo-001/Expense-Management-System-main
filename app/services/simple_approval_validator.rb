class SimpleApprovalValidator
  def validate(expense_sheet, manual_approval_line = nil)
    # 수동으로 지정된 승인 라인이 있으면 사용
    if manual_approval_line.present?
      return { valid: true, approval_line: manual_approval_line }
    end
    
    # 경비 항목들의 경비 코드 확인
    expense_codes = expense_sheet.expense_items.map(&:expense_code).uniq
    
    # 승인 라인 결정
    approval_line = determine_approval_line(expense_sheet, expense_codes)
    
    if approval_line.present?
      { valid: true, approval_line: approval_line }
    else
      { valid: false, errors: ['승인 라인을 결정할 수 없습니다'] }
    end
  end
  
  private
  
  def determine_approval_line(expense_sheet, expense_codes)
    # 가장 복잡한 승인 규칙 선택
    max_approval_line = []
    
    expense_codes.each do |expense_code|
      next unless expense_code.approval_rule.present?
      
      approval_rule = expense_code.approval_rule
      code_items = expense_sheet.expense_items.where(expense_code: expense_code)
      code_total = code_items.sum(:amount)
      
      case approval_rule['type']
      when 'amount_based'
        # 금액 기반 승인 규칙
        rules = approval_rule['rules'] || []
        rules.each do |rule|
          max_amount = rule['max_amount']
          if max_amount.nil? || code_total > max_amount.to_i
            approvers = rule['approvers'] || []
            if approvers.length > max_approval_line.length
              max_approval_line = approvers
            end
          else
            approvers = rule['approvers'] || []
            if approvers.length > max_approval_line.length
              max_approval_line = approvers
            end
            break
          end
        end
      when 'fixed'
        # 고정 승인자
        approvers = approval_rule['approvers'] || []
        if approvers.length > max_approval_line.length
          max_approval_line = approvers
        end
      when 'custom'
        # 사용자 정의 승인 라인
        approvers = approval_rule['custom_line'] || []
        if approvers.length > max_approval_line.length
          max_approval_line = approvers
        end
      end
    end
    
    max_approval_line.presence
  end
end