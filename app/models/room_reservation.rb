class RoomReservation < ApplicationRecord
  # 관계 설정
  belongs_to :room
  belongs_to :user
  belongs_to :recurring_reservation_rule, optional: true
  
  # Validation
  validates :reservation_date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :purpose, presence: true
  
  validate :end_time_after_start_time
  validate :no_time_conflict
  validate :not_in_past
  validate :within_one_year
  
  # 스코프
  scope :upcoming, -> { where('reservation_date >= ?', Date.today).order(:reservation_date, :start_time) }
  scope :past, -> { where('reservation_date < ?', Date.today).order(reservation_date: :desc, start_time: :desc) }
  scope :for_date, ->(date) { where(reservation_date: date) }
  scope :for_room, ->(room) { where(room: room) }
  scope :for_user, ->(user) { where(user: user) }
  
  private
  
  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, '종료 시간은 시작 시간 이후여야 합니다') if end_time <= start_time
  end
  
  def no_time_conflict
    return unless room && reservation_date && start_time && end_time
    
    conflicting = RoomReservation.where(room: room, reservation_date: reservation_date)
                                 .where.not(id: id)
                                 .where('(start_time < ? AND end_time > ?) OR (start_time < ? AND end_time > ?) OR (start_time >= ? AND end_time <= ?)',
                                       end_time, start_time, end_time, end_time, start_time, end_time)
                                 .includes(:user)
    
    if conflicting.exists?
      conflict = conflicting.first
      conflict_time = "#{conflict.start_time.strftime('%H:%M')} - #{conflict.end_time.strftime('%H:%M')}"
      conflict_user = conflict.user.name
      errors.add(:base, "겹치는 예약이 있습니다: #{conflict_user}님의 #{conflict_time} 예약")
    end
  end
  
  def not_in_past
    return unless reservation_date
    errors.add(:reservation_date, '과거 날짜는 예약할 수 없습니다') if reservation_date < Date.today && new_record?
  end
  
  def within_one_year
    return unless reservation_date
    max_date = Date.today + 1.year
    if reservation_date > max_date
      errors.add(:reservation_date, "오늘부터 1년 이내(#{max_date.strftime('%Y년 %m월 %d일')}까지)만 예약 가능합니다")
    end
  end
end
