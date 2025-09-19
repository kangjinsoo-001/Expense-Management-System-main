class RecurringReservationRule < ApplicationRecord
  # 관계 설정
  has_many :room_reservations, dependent: :nullify
  
  # 상수 정의
  FREQUENCIES = %w[daily weekly monthly].freeze
  WEEKDAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze
  
  # Validation
  validates :frequency, presence: true, inclusion: { in: FREQUENCIES }
  validates :end_date, presence: true
  validate :valid_days_of_week
  validate :end_date_in_future
  
  # 직렬화 (Rails 8 방식 - JSON coder 사용)
  serialize :days_of_week, coder: JSON
  
  private
  
  def valid_days_of_week
    return unless frequency == 'weekly' && days_of_week.present?
    
    invalid_days = days_of_week - WEEKDAYS
    errors.add(:days_of_week, "잘못된 요일이 포함되어 있습니다: #{invalid_days.join(', ')}") if invalid_days.any?
  end
  
  def end_date_in_future
    return unless end_date
    errors.add(:end_date, '종료 날짜는 오늘 이후여야 합니다') if end_date < Date.today
  end
end
