class ApprovalRequestStep < ApplicationRecord
  belongs_to :approval_request
  belongs_to :approver, class_name: 'User'
  
  # 상수
  ROLES = %w[approve reference].freeze
  STATUSES = %w[pending approved rejected].freeze
  APPROVAL_TYPES = %w[all_required any_one].freeze
  
  # 검증
  validates :step_order, presence: true, numericality: { greater_than: 0 }
  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :approval_type, inclusion: { in: APPROVAL_TYPES }, allow_nil: true
  
  # 스코프
  scope :ordered, -> { order(:step_order) }
  scope :for_step, ->(step) { where(step_order: step) }
  scope :approvers, -> { where(role: 'approve') }
  scope :referrers, -> { where(role: 'reference') }  # references는 ActiveRecord 예약어라 referrers로 변경
  scope :pending, -> { where(status: 'pending') }
  scope :actioned, -> { where.not(status: 'pending') }
  
  # 인스턴스 메서드
  def approve!(comment = nil)
    update!(
      status: 'approved',
      comment: comment,
      actioned_at: Time.current
    )
  end
  
  def reject!(comment)
    update!(
      status: 'rejected', 
      comment: comment,
      actioned_at: Time.current
    )
  end
  
  def can_action?(user)
    approver_id == user.id && status == 'pending' && role == 'approve'
  end
  
  def actioned?
    status != 'pending'
  end
  
  def approved?
    status == 'approved'
  end
  
  def rejected?
    status == 'rejected'
  end
  
  # 동일 스텝의 다른 승인자들
  def same_step_approvers
    approval_request.approval_request_steps
                   .for_step(step_order)
                   .approvers
                   .where.not(id: id)
  end
  
  # 현재 스텝이 완료되었는지 확인
  def step_completed?
    if approval_type == 'all_required'
      # 모든 승인자가 승인해야 함
      same_step_approvers.all?(&:approved?) && approved?
    else
      # 한 명만 승인하면 됨
      same_step_approvers.any?(&:approved?) || approved?
    end
  end
end