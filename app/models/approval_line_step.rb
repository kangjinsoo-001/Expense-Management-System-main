class ApprovalLineStep < ApplicationRecord
  belongs_to :approval_line
  belongs_to :approver, class_name: 'User'
  
  # Enum 정의
  enum :role, { approve: 'approve', reference: 'reference' }, prefix: true
  enum :approval_type, { all_required: 'all_required', single_allowed: 'single_allowed' }, prefix: true
  
  # 검증
  validates :step_order, presence: true, numericality: { greater_than: 0 }
  validates :role, presence: true
  validates :approver_id, uniqueness: { scope: [:approval_line_id, :step_order], 
                                       message: '같은 단계에 동일한 승인자를 중복 지정할 수 없습니다' }
  
  # 승인 타입은 승인자가 여러 명일 때만 필수
  validate :approval_type_required_for_multiple_approvers
  
  # 스코프
  scope :ordered, -> { order(:step_order) }
  scope :approvers, -> { where(role: 'approve') }
  scope :referrers, -> { where(role: 'reference') }  # references는 Rails 예약어이므로 referrers로 변경
  scope :for_step, ->(step) { where(step_order: step) }
  
  # 콜백
  after_destroy :reorder_subsequent_steps
  
  # 인스턴스 메서드
  def approval_type_display
    return nil unless role_approve?
    
    case approval_type
    when 'all_required'
      '전체 합의'
    when 'single_allowed'
      '단독 가능'
    else
      nil
    end
  end
  
  def role_display
    case role
    when 'approve'
      '승인'
    when 'reference'
      '참조'
    else
      role
    end
  end
  
  private
  
  def reorder_subsequent_steps
    approval_line.approval_line_steps
                 .where('step_order > ?', step_order)
                 .update_all('step_order = step_order - 1')
  end
  
  def approval_type_required_for_multiple_approvers
    return unless role_approve?
    
    same_step_approvers = approval_line.approval_line_steps
                                      .where(step_order: step_order, role: 'approve')
                                      .where.not(id: id)
    
    if same_step_approvers.exists? && approval_type.blank?
      errors.add(:approval_type, '같은 단계에 승인자가 여러 명인 경우 승인 방식을 지정해야 합니다')
    end
  end
end
