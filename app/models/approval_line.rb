class ApprovalLine < ApplicationRecord
  belongs_to :user
  
  # 관계 설정
  has_many :approval_line_steps, dependent: :destroy
  has_many :approval_requests, dependent: :nullify  # 결재선 삭제 시 참조만 끊음
  
  # nested attributes
  accepts_nested_attributes_for :approval_line_steps, 
    allow_destroy: true, 
    reject_if: proc { |attributes| 
      # _destroy가 true가 아니고, approver_id가 비어있으면 거부
      attributes['_destroy'] != '1' && attributes['_destroy'] != true && attributes['approver_id'].blank?
    }
  
  # 콜백
  before_create :set_default_position
  
  # 콜백 - 저장 전 name trim 처리
  before_validation :strip_name
  
  # 검증
  validates :name, presence: { message: '결재선 이름을 입력하세요' }, 
            uniqueness: { scope: :user_id, message: '이미 사용 중인 결재선 이름입니다', case_sensitive: false }
  validates :is_active, inclusion: { in: [true, false] }
  validate :must_have_at_least_one_step
  
  # 스코프
  scope :active, -> { where(deleted_at: nil) }  # 소프트 삭제되지 않은 것만
  scope :is_active, -> { where(is_active: true) }  # 활성화된 것만
  scope :for_user, ->(user) { where(user: user) }
  scope :ordered_by_position, -> { order(:position, :created_at) }
  
  # 인스턴스 메서드
  def total_steps
    approval_line_steps.maximum(:step_order) || 0
  end
  
  def approvers_for_step(step_order)
    approval_line_steps.for_step(step_order).approvers
  end
  
  def has_approver?(user)
    approval_line_steps.where(approver_id: user.id).exists?
  end
  
  # 특정 승인자 그룹에 속한 승인자가 결재선에 포함되어 있는지 확인
  def has_approver_from_group?(approver_group)
    return false unless approver_group
    
    # 결재선의 모든 승인자 ID를 가져옴
    approver_ids = approval_line_steps.approvers.pluck(:approver_id)
    
    # 해당 그룹의 승인자들과 교집합이 있는지 확인
    group_approver_ids = approver_group.members.pluck(:id)
    
    (approver_ids & group_approver_ids).any?
  end
  
  def duplicate_for_user(new_user)
    new_line = self.dup
    new_line.user = new_user
    new_line.name = "#{name} (복사본)"
    new_line.is_active = true
    
    if new_line.save
      approval_line_steps.each do |step|
        new_step = step.dup
        new_step.approval_line = new_line
        new_step.save
      end
    end
    
    new_line
  end
  
  # 클래스 메서드 - 순서 재정렬
  def self.reorder_for_user(user, ordered_ids)
    transaction do
      ordered_ids.each_with_index do |id, index|
        where(user: user, id: id).update_all(position: index + 1)
      end
    end
  end
  
  private
  
  def strip_name
    self.name = name.strip if name.present?
  end
  
  def set_default_position
    # 같은 사용자의 마지막 position 값 + 1로 설정
    max_position = user.approval_lines.maximum(:position) || 0
    self.position = max_position + 1
  end
  
  def must_have_at_least_one_step
    # marked_for_destruction?을 확인하여 삭제 예정인 단계는 제외
    active_steps = approval_line_steps.reject(&:marked_for_destruction?)
    
    if active_steps.empty?
      errors.add(:base, '최소 하나 이상의 승인 단계가 필요합니다')
    end
  end
end
