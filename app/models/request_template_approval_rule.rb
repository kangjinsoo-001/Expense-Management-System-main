class RequestTemplateApprovalRule < ApplicationRecord
  # 관계 설정
  belongs_to :request_template
  belongs_to :approver_group
  
  # 검증 규칙
  # condition은 비어있을 수 있음 (비어있으면 모든 경우에 적용)
  validates :order, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
  validates :is_active, inclusion: { in: [true, false] }
  
  # 콜백
  before_validation :set_order_if_blank, on: :create
  
  # 스코프
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:order) }
  
  # 조건 평가 (신청서 폼 데이터 기반)
  def evaluate(context = {})
    return true if condition.blank?
    
    # 필드 값으로 조건식의 변수를 치환
    evaluated_condition = condition.dup
    
    # #필드키 형식을 실제 값으로 치환
    context.each do |field_key, field_value|
      # nil 값 처리
      if field_value.nil?
        evaluated_condition.gsub!("##{field_key}", "nil")
      # 숫자 비교를 위한 처리
      elsif field_value.is_a?(Numeric) || field_value.to_s.match?(/\A\d+(\.\d+)?\z/)
        evaluated_condition.gsub!("##{field_key}", field_value.to_s)
      # 날짜 처리
      elsif field_value.is_a?(Date) || field_value.is_a?(Time) || field_value.is_a?(DateTime)
        evaluated_condition.gsub!("##{field_key}", "'#{field_value.to_s}'")
      # 문자열은 따옴표로 감싸기
      else
        evaluated_condition.gsub!("##{field_key}", "'#{field_value.to_s.gsub("'", "\\'")}'")
      end
    end
    
    # 안전한 평가를 위한 기본 검증
    return false unless evaluated_condition.match?(/\A[\s\d\w<>=!&|().'"-]+\z/)
    
    # 조건식 평가
    begin
      eval(evaluated_condition)
    rescue => e
      Rails.logger.error "승인 규칙 조건 평가 실패: #{e.message}"
      false
    end
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
  
  # 계층적 승인 규칙 충족 확인 (상위 권한이 있으면 하위 권한도 충족)
  def satisfied_with_hierarchy?(approval_line)
    return false unless approval_line

    approvers = approval_line.approval_line_steps
                            .approvers
                            .includes(:approver)
                            .map(&:approver)

    # 이 그룹이나 더 높은 우선순위 그룹의 멤버가 있는지 확인
    required_groups = [approver_group] + approver_group.higher_priority_groups.to_a
    
    approvers.any? do |approver|
      required_groups.any? { |group| group.has_member?(approver) }
    end
  end
  
  # 사용자가 이미 필요한 권한을 가지고 있는지 확인
  def already_satisfied_by_user?(user)
    return false unless user
    
    # 사용자가 이 그룹이나 더 높은 우선순위 그룹의 멤버인지 확인
    required_groups = [approver_group] + approver_group.higher_priority_groups.to_a
    
    required_groups.any? { |group| group.has_member?(user) }
  end
  
  private
  
  def set_order_if_blank
    if order.blank?
      template_id = request_template_id
      max_order = RequestTemplateApprovalRule.where(request_template_id: template_id).maximum(:order) || 0
      self.order = max_order + 1
    end
  end
end