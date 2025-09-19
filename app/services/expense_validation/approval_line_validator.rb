module ExpenseValidation
  class ApprovalLineValidator
    attr_reader :errors, :warnings
    
    def initialize(expense_item)
      @expense_item = expense_item
      @errors = []
      @warnings = []
    end
    
    # 결재선이 승인 규칙을 충족하는지 검증
    def validate
      # expense_item의 approval_line 또는 expense_sheet의 approval_line 확인
      approval_line = @expense_item.approval_line || @expense_item.expense_sheet&.approval_line
      return true unless approval_line
      return true unless @expense_item.expense_code
      
      @errors.clear
      @warnings.clear
      
      # 경비 코드의 승인 규칙 가져오기
      approval_rules = @expense_item.expense_code
                                   .expense_code_approval_rules
                                   .active
                                   .ordered
      
      # 승인 규칙이 없는데 결재선이 설정된 경우 경고
      if approval_rules.empty?
        check_unnecessary_approval_line
        return true
      end
      
      # 평가된 규칙 찾기 (과도한 승인자 체크용)
      triggered_rules_for_check = approval_rules.select { |rule| rule.evaluate(@expense_item) }
      
      # 각 규칙에 대해 검증
      approval_rules.each do |rule|
        validate_rule(rule)
      end
      
      # 과도한 승인자 체크 (사용자 권한 관계없이 모든 triggered rules 사용)
      check_excessive_approvers(triggered_rules_for_check)
      
      @errors.empty?
    end
    
    # 검증 에러 메시지
    def error_messages
      @errors.map { |error| error[:message] }
    end
    
    # 상세 검증 결과
    def validation_result
      {
        valid: @errors.empty?,
        errors: @errors,
        warnings: @warnings,
        expense_item_id: @expense_item.id,
        expense_code: @expense_item.expense_code.name_with_code,
        amount: @expense_item.amount
      }
    end
    
    private
    
    # 승인 규칙이 없는데 결재선이 설정된 경우 체크
    def check_unnecessary_approval_line
      approval_line = @expense_item.approval_line || @expense_item.expense_sheet&.approval_line
      return unless approval_line
      
      # 결재선의 승인자들이 속한 그룹 확인
      approvers = approval_line.approval_line_steps
                              .approvers
                              .includes(approver: :approver_groups)
                              .map(&:approver)
      
      # 각 승인자의 최고 우선순위 그룹만 가져오기
      highest_groups = approvers.map do |approver|
        approver.approver_groups.max_by(&:priority)
      end.compact.uniq
      
      if highest_groups.any?
        # 우선순위 높은 순(숫자가 큰 순)으로 정렬
        sorted_groups = highest_groups.sort_by { |g| -g.priority }
        group_names = sorted_groups.map(&:name).join(', ')
        @warnings << {
          type: 'unnecessary_approval',
          level: 'warning',
          message: "필수 아님: #{group_names}",
          approver_groups: sorted_groups.map { |g| { name: g.name, priority: g.priority } }
        }
      end
    end
    
    # 과도한 승인자 체크
    def check_excessive_approvers(approval_rules)
      return if approval_rules.empty?
      
      approval_line = @expense_item.approval_line || @expense_item.expense_sheet&.approval_line
      return unless approval_line
      
      # 필요한 최고 우선순위 찾기
      required_priorities = approval_rules.map do |rule|
        rule.approver_group.priority
      end
      max_required_priority = required_priorities.max || 0
      
      # 현재 결재선의 승인자들이 속한 그룹 확인
      approvers = approval_line.approval_line_steps
                              .approvers
                              .includes(approver: :approver_groups)
                              .map(&:approver)
      
      # 각 승인자의 최고 우선순위 그룹만 가져오기
      highest_groups_per_approver = approvers.map do |approver|
        approver.approver_groups.max_by(&:priority)
      end.compact
      
      # 중복 제거하고 우선순위 계산
      unique_groups = highest_groups_per_approver.uniq
      max_actual_priority = unique_groups.map(&:priority).max || 0
      
      # 필요 이상으로 높은 직급이 포함된 경우 경고
      if max_actual_priority > max_required_priority
        excessive_groups = unique_groups.select { |g| g.priority > max_required_priority }
        # 우선순위 높은 순(숫자가 큰 순)으로 정렬
        sorted_excessive_groups = excessive_groups.sort_by { |g| -g.priority }
        required_group_names = approval_rules.map { |r| r.approver_group.name }.uniq
        excessive_group_names = sorted_excessive_groups.map(&:name)
        
        @warnings << {
          type: 'excessive_approver',
          level: 'warning',
          message: "필수 아님: #{excessive_group_names.join(', ')}",
          excessive_groups: sorted_excessive_groups.map { |g| { name: g.name, priority: g.priority } },
          required_groups: required_group_names,
          required_priority: max_required_priority,
          actual_priority: max_actual_priority
        }
      end
    end
    
    # 개별 규칙 검증
    def validate_rule(rule)
      # 조건 평가
      return unless rule.evaluate(@expense_item)
      
      Rails.logger.info "검증 중인 규칙: #{rule.condition} → #{rule.approver_group.name}"
      
      # 사용자의 최고 권한이 이 규칙이 요구하는 권한 이상인 경우만 스킵
      # 예: 사용자가 조직리더(6)이고 규칙이 보직자(4) 요구 → 스킵
      # 예: 사용자가 보직자(4)이고 규칙이 CEO(10) 요구 → 검증 필요
      user = @expense_item.expense_sheet&.user
      if user
        user_max_priority = user.approver_groups.maximum(:priority) || 0
        if user_max_priority >= rule.approver_group.priority
          Rails.logger.info "  → 사용자가 이미 충분한 권한 보유 (사용자: #{user_max_priority}, 요구: #{rule.approver_group.priority})"
          return
        end
      end
      
      # 결재선에서 규칙이 충족되는지 확인
      approval_line = @expense_item.approval_line || @expense_item.expense_sheet&.approval_line
      
      if rule.satisfied_with_hierarchy?(approval_line)
        Rails.logger.info "  → 결재선이 규칙 충족"
      else
        Rails.logger.info "  → 결재선이 규칙 미충족"
        required_group = rule.approver_group
        
        # 상세한 에러 메시지 생성
        error_detail = build_error_detail(rule, required_group, approval_line)
        @errors << error_detail
      end
    end
    
    # 에러 상세 정보 생성
    def build_error_detail(rule, required_group, approval_line)
      # 현재 결재선의 승인자들이 속한 그룹 확인
      approvers = approval_line.approval_line_steps
                              .approvers
                              .includes(approver: :approver_groups)
                              .map(&:approver)
      
      approver_groups = approvers.flat_map(&:approver_groups).uniq
      max_priority = approver_groups.map(&:priority).max || 0
      
      {
        rule_id: rule.id,
        condition: rule.condition,
        required_group: {
          name: required_group.name,
          priority: required_group.priority
        },
        current_groups: approver_groups.map { |g| 
          { name: g.name, priority: g.priority } 
        },
        message: build_error_message(rule, required_group, max_priority)
      }
    end
    
    # 사용자 친화적인 에러 메시지 생성
    def build_error_message(rule, required_group, max_priority)
      # 간단한 형식으로 변경: "승인 필요: 그룹명"
      "승인 필요: #{required_group.name}"
    end
    
    # 조건식을 사람이 읽기 쉬운 형태로 변환
    def describe_condition(condition)
      return "이 경비 항목은" if condition.blank?
      
      # 간단한 패턴 매칭으로 설명 생성
      case condition
      when /#금액\s*>\s*(\d+)/
        amount = $1.to_i
        formatted_amount = number_to_currency(amount)
        "금액이 #{formatted_amount}을 초과하는 경우"
      when /#금액\s*>=\s*(\d+)/
        amount = $1.to_i
        formatted_amount = number_to_currency(amount)
        "금액이 #{formatted_amount} 이상인 경우"
      when /#금액\s*<=\s*(\d+)/
        amount = $1.to_i
        formatted_amount = number_to_currency(amount)
        "금액이 #{formatted_amount} 이하인 경우"
      when /#(\w+)\s*>\s*(\d+)/
        field = $1
        value = $2
        "#{field}이(가) #{value}을(를) 초과하는 경우"
      else
        "조건(#{condition})을 만족하는 경우"
      end
    end
    
    def number_to_currency(amount)
      return "₩0" if amount.nil? || amount == 0
      
      # 천 단위 구분 쉼표 추가
      formatted = amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
      "₩#{formatted}"
    end
  end
end