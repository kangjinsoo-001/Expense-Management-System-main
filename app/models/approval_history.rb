class ApprovalHistory < ApplicationRecord
  belongs_to :approval_request
  belongs_to :approver, class_name: 'User'
  
  # Enum 정의
  enum :role, { approve: 'approve', reference: 'reference' }, prefix: true
  enum :action, { 
    approve: 'approve',      # 승인
    reject: 'reject',        # 반려
    view: 'view',           # 열람 (참조자)
    cancel: 'cancel',       # 취소
    reset: 'reset'          # AI 검증으로 인한 승인 초기화
  }, prefix: true
  
  # 검증
  validates :step_order, presence: true, numericality: { greater_than_or_equal_to: 0 }  # 0을 허용 (reset의 경우)
  validates :action, presence: true
  validates :approved_at, presence: true
  validates :comment, presence: true, if: :action_reject?  # reject일 때만 comment 필수
  
  # 재승인 상황을 고려한 커스텀 유니크 검증
  validate :validate_unique_approval, unless: -> { action_view? || action_reset? }
  
  def validate_unique_approval
    expense_item = approval_request.expense_item
    
    # expense_item이 nil인 경우 처리
    return unless expense_item
    
    # 재승인 상황인 경우
    if expense_item.needs_reapproval?
      # 재승인 요청 이후의 동일한 step_order에서만 중복 체크
      budget_approved_at = expense_item.budget_approved_at || Time.current
      existing = ApprovalHistory.where(
        approval_request_id: approval_request_id,
        approver_id: approver_id,
        step_order: step_order
      ).where('approved_at > ?', budget_approved_at)
      
      if persisted?
        existing = existing.where.not(id: id)
      end
      
      if existing.exists?
        errors.add(:approver_id, '이미 처리한 승인 단계입니다')
      end
    else
      # 일반 상황에서는 기존 로직 적용
      existing = ApprovalHistory.where(
        approval_request_id: approval_request_id,
        approver_id: approver_id,
        step_order: step_order
      )
      
      if persisted?
        existing = existing.where.not(id: id)
      end
      
      if existing.exists?
        errors.add(:approver_id, '이미 처리한 승인 단계입니다')
      end
    end
  end
  
  # 콜백
  before_validation :set_approved_at
  
  # 스코프
  scope :ordered, -> { order(approved_at: :desc) }
  scope :chronological, -> { order(approved_at: :asc) }
  scope :approvals, -> { where(action: 'approve') }
  scope :rejections, -> { where(action: 'reject') }
  scope :views, -> { where(action: 'view') }
  scope :for_step, ->(step) { where(step_order: step) }
  scope :by_approver, ->(user) { where(approver: user) }
  
  # 인스턴스 메서드
  def action_display
    case action
    when 'approve'
      '승인'
    when 'reject'
      '반려'
    when 'view'
      '열람'
    when 'cancel'
      '취소'
    when 'reset'
      'AI 검증 초기화'
    else
      action
    end
  end
  
  def role_display
    case role
    when 'approve'
      '승인자'
    when 'reference'
      '참조자'
    else
      role
    end
  end
  
  def summary
    "#{approver.name}님이 #{approved_at.strftime('%Y-%m-%d %H:%M')}에 #{action_display}"
  end
  
  private
  
  def set_approved_at
    self.approved_at ||= Time.current
  end
end
