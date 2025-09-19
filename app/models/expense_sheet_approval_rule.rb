class ExpenseSheetApprovalRule < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :approver_group
  belongs_to :submitter_group, class_name: 'ApproverGroup', optional: true
  
  validates :order, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validates :approver_group, presence: true
  
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:order) }
  
  before_validation :set_order_if_blank, on: :create
  
  # 조건 평가 (제출자 기반)
  def evaluate(context = {})
    # 제출자 그룹 조건 확인
    if submitter_group.present?
      submitter = context[:submitter]
      return false unless submitter && submitter_group.has_member?(submitter)
    end
    
    # 일반 조건 평가
    return true if condition.blank?
    
    evaluate_condition(condition, context)
  end
  
  # 기존 satisfied_by? 메서드와 동일한 로직
  def satisfied_by?(approval_line)
    return false unless approval_line
    
    # 결재선의 모든 승인자 조회 (참조자는 제외)
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
    max_priority >= approver_group.priority
  end
  
  # 규칙 설명 생성
  def description
    desc = []
    
    if submitter_group.present?
      desc << "제출자가 #{submitter_group.name}일 때"
    end
    
    if condition.present?
      desc << format_condition(condition)
    end
    
    desc << "#{approver_group.name} 승인 필요"
    
    desc.join(", ")
  end
  
  private
  
  def set_order_if_blank
    if order.blank?
      max_order = self.class.where(organization_id: organization_id).maximum(:order) || 0
      self.order = max_order + 1
    end
  end
  
  def evaluate_condition(condition, context)
    # #총금액, #항목수, #경비코드 등 처리
    if condition.match?(/#총금액\s*[><=]+\s*\d+/)
      total_amount = context[:total_amount] || 0
      evaluate_amount_condition(condition.gsub('#총금액', total_amount.to_s))
    elsif condition.match?(/#항목수\s*[><=]+\s*\d+/)
      item_count = context[:item_count] || 0
      evaluate_count_condition(condition.gsub('#항목수', item_count.to_s))
    elsif condition.match?(/#경비코드:/)
      # 경비 코드 존재 여부 확인
      evaluate_expense_code_condition(condition, context)
    else
      true
    end
  rescue => e
    Rails.logger.error "승인 규칙 조건 평가 실패: #{e.message}"
    false
  end
  
  def evaluate_amount_condition(condition_str)
    # 금액 조건 평가 (>, >=, <, <=, ==)
    if condition_str.match?(/(\d+)\s*([><=]+)\s*(\d+)/)
      match = condition_str.match(/(\d+)\s*([><=]+)\s*(\d+)/)
      left = match[1].to_i
      operator = match[2]
      right = match[3].to_i
      
      case operator
      when '>' then left > right
      when '>=' then left >= right
      when '<' then left < right
      when '<=' then left <= right
      when '==' then left == right
      else false
      end
    else
      false
    end
  end
  
  def evaluate_count_condition(condition_str)
    # 항목수 조건 평가 (>, >=, <, <=, ==)
    evaluate_amount_condition(condition_str)
  end
  
  def evaluate_expense_code_condition(condition, context)
    # #경비코드:CODE1,CODE2 형식 처리
    if condition.match?(/#경비코드:([A-Z0-9,]+)/)
      match = condition.match(/#경비코드:([A-Z0-9,]+)/)
      required_codes = match[1].split(',').map(&:strip)
      sheet_codes = context[:expense_codes] || []
      
      # 필요한 코드 중 하나라도 시트에 포함되어 있으면 true
      (required_codes & sheet_codes).any?
    else
      false
    end
  end
  
  def format_condition(cond)
    if cond.match?(/#총금액\s*([><=]+)\s*(\d+)/)
      match = cond.match(/#총금액\s*([><=]+)\s*(\d+)/)
      operator = match[1]
      amount = match[2].to_i
      formatted_amount = ActionController::Base.helpers.number_to_currency(amount, unit: "", precision: 0)
      "총금액 #{operator} #{formatted_amount}원"
    elsif cond.match?(/#항목수\s*([><=]+)\s*(\d+)/)
      match = cond.match(/#항목수\s*([><=]+)\s*(\d+)/)
      operator = match[1]
      count = match[2]
      "항목수 #{operator} #{count}개"
    elsif cond.match?(/#경비코드:([A-Z0-9,]+)/)
      match = cond.match(/#경비코드:([A-Z0-9,]+)/)
      codes = match[1].split(',').map(&:strip)
      code_names = ExpenseCode.where(code: codes).pluck(:code, :name).map { |c, n| "#{c}(#{n})" }.join(', ')
      "경비코드 포함: #{code_names}"
    else
      cond
    end
  end
end