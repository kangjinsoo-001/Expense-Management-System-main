class ApproverGroupMember < ApplicationRecord
  belongs_to :approver_group
  belongs_to :user
  belongs_to :added_by, class_name: 'User'

  validates :added_at, presence: true
  validates :user_id, uniqueness: { scope: :approver_group_id, 
                                    message: '는 이미 이 그룹의 멤버입니다' }

  before_validation :set_added_at, on: :create

  scope :ordered, -> { includes(:user).order('users.name') }

  private

  def set_added_at
    self.added_at ||= Time.current
  end
end
