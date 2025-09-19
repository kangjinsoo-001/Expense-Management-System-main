class ApproverGroup < ApplicationRecord
  belongs_to :created_by, class_name: 'User'
  has_many :approver_group_members, dependent: :destroy
  has_many :members, through: :approver_group_members, source: :user
  has_many :expense_code_approval_rules, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :priority, presence: true, 
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 10 }
  validates :is_active, inclusion: { in: [true, false] }

  scope :active, -> { where(is_active: true) }
  scope :by_priority, -> { order(priority: :desc) }
  scope :ordered, -> { order(:priority) }

  # 사용자가 이 그룹의 멤버인지 확인
  def has_member?(user)
    members.include?(user)
  end

  # 사용자 추가
  def add_member(user, added_by_user)
    return false if has_member?(user)
    
    approver_group_members.create!(
      user: user,
      added_by: added_by_user,
      added_at: Time.current
    )
  end

  # 사용자 제거
  def remove_member(user)
    approver_group_members.find_by(user: user)&.destroy
  end

  # 이 그룹보다 높은 우선순위 그룹들 조회
  def higher_priority_groups
    self.class.active.where('priority > ?', priority)
  end

  # 사용 중인지 확인 (승인 규칙에서 참조)
  def in_use?
    expense_code_approval_rules.exists?
  end
  
  # 이름과 우선순위 표시
  def name_with_priority
    "#{name} (우선순위 #{priority})"
  end
end
