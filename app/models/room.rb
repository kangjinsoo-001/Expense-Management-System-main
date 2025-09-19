class Room < ApplicationRecord
  # 관계 설정
  belongs_to :room_category, optional: true  # 마이그레이션 중에는 optional
  has_many :room_reservations, dependent: :destroy
  
  # Validation
  validates :name, presence: true, uniqueness: true
  validates :category, presence: true, inclusion: { in: %w[강남 판교 서초] }  # 임시 유지
  
  # 스코프
  scope :ordered, -> { order(:category, :name) }
  scope :by_location, ->(location) { where(category: location) }
  scope :by_category, ->(category) { where(category: category) }
  
  # 카테고리별 정렬을 위한 커스텀 순서 (강남 → 판교 → 서초)
  scope :ordered_by_category, -> {
    order(
      Arel.sql("CASE category 
        WHEN '강남' THEN 1 
        WHEN '판교' THEN 2 
        WHEN '서초' THEN 3 
        ELSE 4 END"),
      Arel.sql("CASE 
        WHEN name LIKE '%파이%' THEN 1
        WHEN name LIKE '%베타%' THEN 2
        WHEN name LIKE '%카파%' THEN 3
        WHEN name LIKE '%알파%' THEN 4
        WHEN name LIKE '#1%' THEN 5
        WHEN name LIKE '#2%' THEN 6
        WHEN name LIKE '#3%' THEN 7
        WHEN name LIKE '#4%' THEN 8
        ELSE 99 END"),
      :name
    )
  }
  
  # 지점 추출 메서드 (호환성 유지)
  def location
    category
  end
end
