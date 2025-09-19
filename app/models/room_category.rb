class RoomCategory < ApplicationRecord
  # 관계 설정
  has_many :rooms, dependent: :restrict_with_error
  
  # 검증 규칙
  validates :name, presence: true, uniqueness: true
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }
  validates :is_active, inclusion: { in: [true, false] }
  
  # 스코프
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:display_order, :id) }
  
  # 활성 회의실 수
  def active_rooms_count
    rooms.count
  end
  
  # 표시용 이름 (회의실 수 포함)
  def display_name_with_count
    "#{name} (#{active_rooms_count})"
  end
end