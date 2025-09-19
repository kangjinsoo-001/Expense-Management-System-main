class ExpenseCodeApprovalRule < ApplicationRecord
  belongs_to :expense_code
  belongs_to :approver_group

  # condition은 빈 문자열이어도 유효 (모든 경우에 적용)
  validates :order, 
            numericality: { greater_than_or_equal_to: 1 }, 
            allow_nil: true
  validates :is_active, inclusion: { in: [true, false] }

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:order) }

  before_validation :set_order_if_blank, on: :create

  # 조건 평가
  def evaluate(expense_item)
    return true if condition.blank?
    
    parser = ExpenseValidation::ConditionParser.new(condition)
    parser.evaluate(expense_item: expense_item)
  rescue ExpenseValidation::ConditionParser::ParseError => e
    Rails.logger.error "조건식 평가 오류: #{e.message}"
    false
  end

  # 규칙이 충족되었는지 확인 (결재선에 필요한 그룹 멤버가 있는지)
  def satisfied_by?(approval_line)
    return false unless approval_line

    # 결재선의 모든 승인자 조회
    approvers = approval_line.approval_line_steps
                            .approvers
                            .includes(:approver)
                            .map(&:approver)

    # 승인자 중 이 그룹의 멤버가 있는지 확인
    approvers.any? { |approver| approver_group.has_member?(approver) }
  end

  # 위계를 고려한 충족 확인 (상위 그룹도 체크)
  def satisfied_with_hierarchy?(approval_line)
    return false unless approval_line

    # 결재선의 승인자들 중 최고 권한 확인
    approvers = approval_line.approval_line_steps
                            .approvers
                            .includes(approver: :approver_groups)
                            .map(&:approver)
    
    # 결재선에 있는 승인자들의 최고 권한 우선순위
    max_priority = approvers.flat_map(&:approver_groups)
                           .map(&:priority)
                           .max || 0
    
    # 결재선의 최고 권한이 요구되는 권한 이상인지 확인
    # 예: CEO(10) 필요한데 조직리더(6)만 있으면 false
    # 예: 보직자(4) 필요한데 조직리더(6) 있으면 true
    max_priority >= approver_group.priority
  end
  
  # 사용자가 이미 필요한 권한을 가지고 있는지 확인
  # 사용자의 최고 권한이 이 규칙이 요구하는 권한 이상인 경우만 true
  def already_satisfied_by_user?(user)
    return false unless user
    
    # 사용자가 속한 승인 그룹 중 최고 우선순위 확인
    user_max_priority = user.approver_groups.maximum(:priority) || 0
    
    # 사용자의 최고 권한이 이 규칙이 요구하는 권한 이상인 경우에만 충족
    # 예: 사용자가 조직리더(6)이고 규칙이 보직자(4) 요구 → true
    # 예: 사용자가 보직자(4)이고 규칙이 CEO(10) 요구 → false
    user_max_priority >= approver_group.priority
  end
  
  # 사용자보다 높은 권한의 승인이 필요한지 확인
  def requires_higher_approval_than_user?(user)
    return true unless user
    
    user_max_priority = user.approver_groups.maximum(:priority) || 0
    approver_group.priority > user_max_priority
  end

  private

  def set_order_if_blank
    if order.blank?
      # expense_code_id 사용
      code_id = expense_code_id
      
      # 데이터베이스에서 직접 쿼리
      max_order = ExpenseCodeApprovalRule.where(expense_code_id: code_id).maximum(:order) || 0
      self.order = max_order + 1
      
      Rails.logger.debug "ExpenseCodeApprovalRule: Set order to #{self.order} (max was #{max_order} for expense_code_id #{code_id})"
    end
  end
end
