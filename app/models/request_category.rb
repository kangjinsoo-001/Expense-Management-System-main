class RequestCategory < ApplicationRecord
  # 관계 설정
  has_many :request_templates, dependent: :restrict_with_error
  
  # 검증 규칙
  validates :name, presence: true, uniqueness: true
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }
  validates :is_active, inclusion: { in: [true, false] }
  
  # 스코프
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:display_order, :id) }
  
  # 활성 템플릿 수
  def active_templates_count
    request_templates.active.count
  end
  
  # 표시용 이름 (템플릿 수 포함)
  def display_name_with_count
    "#{name} (#{active_templates_count})"
  end
end
