class ExpenseSheetApprovalValidator
  def initialize
    # item_validator는 필요할 때 생성
  end
  
  def validate(expense_sheet, approval_line)
    errors = []
    warnings = []
    required_groups = []
    
    # 1. 경비 시트 전체 규칙 확인
    sheet_rules = ExpenseSheetApprovalRule.active.ordered
    
    # 경비 코드 목록 수집
    expense_codes = expense_sheet.expense_items
                                 .joins(:expense_code)
                                 .pluck('expense_codes.code')
                                 .uniq
    
    context = {
      submitter: expense_sheet.user,
      total_amount: expense_sheet.total_amount,
      item_count: expense_sheet.expense_items.count,
      expense_codes: expense_codes
    }
    
    # 해당 조건에 맞는 규칙만 필터링
    applicable_rules = sheet_rules.select { |rule| rule.evaluate(context) }
    
    # 2. 개별 경비 항목 규칙 확인
    expense_sheet.expense_items.each do |item|
      if defined?(ExpenseValidation::ApprovalLineValidator)
        begin
          # 각 항목마다 validator 생성
          item_validator = ExpenseValidation::ApprovalLineValidator.new(item)
          item_result = item_validator.validate_expense_item(item, approval_line)
          if item_result[:errors].present?
            errors.concat(Array(item_result[:errors]))
          end
          if item_result[:warnings].present?
            warnings.concat(Array(item_result[:warnings]))
          end
        rescue => e
          Rails.logger.error "경비 항목 검증 중 오류: #{e.message}"
          # 오류 시 기본 검증 실행
          if item.expense_code&.expense_code_approval_rules&.active&.any?
            item.expense_code.expense_code_approval_rules.active.each do |rule|
              unless rule.satisfied_by?(approval_line)
                required_groups << rule.approver_group.name
              end
            end
          end
        end
      else
        # ExpenseValidation::ApprovalLineValidator가 정의되지 않은 경우 기본 검증
        if item.expense_code&.expense_code_approval_rules&.active&.any?
          item.expense_code.expense_code_approval_rules.active.each do |rule|
            unless rule.satisfied_by?(approval_line)
              required_groups << rule.approver_group.name
            end
          end
        end
      end
    end
    
    # 3. 시트 규칙에 대한 결재선 검증
    applicable_rules.each do |rule|
      unless rule.satisfied_by?(approval_line)
        required_groups << rule.approver_group.name
      end
    end
    
    # 4. 메시지 포맷 (기존 형식 준수)
    if required_groups.any?
      unique_groups = required_groups.uniq
      # 우선순위 높은 순으로 정렬 (가능한 경우)
      sorted_groups = sort_groups_by_priority(unique_groups)
      errors << "승인 필요: #{sorted_groups.join(', ')}"
    end
    
    # 과도한 결재선 체크
    excessive_groups = find_excessive_groups(applicable_rules, approval_line, expense_sheet.expense_items)
    if excessive_groups.any?
      warnings << "필수 아님: #{excessive_groups.join(', ')}"
      warnings << "제출은 가능하지만, 불필요한 승인 단계가 포함되어 있습니다."
    end
    
    # 사용자 권한 정보 추가
    user_info = check_user_authority(expense_sheet.user, applicable_rules)
    if user_info.present?
      warnings << user_info
    end
    
    {
      valid: errors.empty?,
      errors: errors.uniq,
      warnings: warnings.uniq
    }
  end
  
  private
  
  def find_excessive_groups(rules, approval_line, expense_items)
    return [] unless approval_line
    
    # 필요한 그룹들의 최대 우선순위 계산
    required_priorities = []
    
    # 시트 규칙에서 필요한 그룹들
    rules.each do |rule|
      required_priorities << rule.approver_group.priority if rule.approver_group
    end
    
    # 경비 항목 규칙에서 필요한 그룹들
    expense_items.each do |item|
      if item.expense_code&.expense_code_approval_rules&.active&.any?
        item.expense_code.expense_code_approval_rules.active.each do |rule|
          required_priorities << rule.approver_group.priority if rule.approver_group
        end
      end
    end
    
    max_required_priority = required_priorities.max || 0
    
    # 결재선에서 과도한 승인자 찾기
    excessive_groups = []
    approval_line.approval_line_steps.approvers.includes(:approver).each do |step|
      approver = step.approver
      if approver.approver_groups.any?
        approver_max_priority = approver.approver_groups.maximum(:priority) || 0
        if approver_max_priority > max_required_priority
          highest_group = approver.approver_groups.find_by(priority: approver_max_priority)
          excessive_groups << highest_group.name if highest_group
        end
      end
    end
    
    excessive_groups.uniq
  end
  
  def sort_groups_by_priority(group_names)
    # 그룹 이름을 우선순위 기준으로 정렬
    groups = ApproverGroup.where(name: group_names).order(priority: :desc)
    groups.pluck(:name)
  end
  
  def check_user_authority(user, rules)
    return nil unless user
    
    user_groups = user.approver_groups
    return nil if user_groups.empty?
    
    user_max_priority = user_groups.maximum(:priority) || 0
    
    # 사용자가 이미 충족하는 규칙이 있는지 확인
    satisfied_groups = []
    rules.each do |rule|
      if rule.approver_group.priority <= user_max_priority
        satisfied_groups << rule.approver_group.name
      end
    end
    
    if satisfied_groups.any?
      highest_user_group = user_groups.order(priority: :desc).first
      "귀하는 이미 #{highest_user_group.name} 권한을 보유하고 있습니다."
    else
      nil
    end
  end
end