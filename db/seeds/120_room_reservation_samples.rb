# 회의실 예약 샘플 데이터 생성
puts "Creating sample room reservations..."

# 기존 예약 데이터 정리 (개발 환경에서만)
RoomReservation.destroy_all if Rails.env.development?

# 사용자와 회의실 가져오기
users = User.limit(20).to_a
rooms = Room.all.to_a

if users.empty? || rooms.empty?
  puts "Skipping room reservations: No users or rooms found"
  return
end

# 지난 7일부터 앞으로 30일까지의 예약 생성 (총 37일)
created_count = 0
(-7..30).each do |day_offset|
  date = Date.today + day_offset.days
  
  # 주말은 예약 적게 생성
  is_weekend = date.saturday? || date.sunday?
  reservation_count = is_weekend ? rand(1..2) : rand(3..6)
  
  # 각 날짜마다 예약 생성
  reservation_count.times do
    room = rooms.sample
    user = users.sample
    
    # 시간대별 가중치 (일반적인 회의 시간 선호)
    time_weights = {
      9 => 8, 10 => 10, 11 => 7, 12 => 3, 13 => 5, 14 => 10, 15 => 8, 16 => 6, 17 => 4
    }
    
    # 가중치에 따른 시간 선택
    weighted_hours = time_weights.flat_map { |hour, weight| [hour] * weight }
    start_hour = weighted_hours.sample
    
    # 지속 시간 (30분, 1시간, 1.5시간, 2시간)
    durations = [0.5, 1, 1.5, 2]
    duration = durations.sample
    
    start_time = Time.zone.parse("#{date} #{start_hour}:00")
    end_time = start_time + duration.hours
    
    # 예약 목적 확장
    purposes = [
      "팀 회의", "프로젝트 미팅", "면접", "교육", "워크샵", "고객 미팅", "전략 회의",
      "브레인스토밍", "1:1 미팅", "부서 회의", "기획 회의", "개발 회의", "마케팅 미팅",
      "디자인 리뷰", "코드 리뷰", "스프린트 계획", "회고", "온보딩", "발표 연습"
    ]
    
    # 특별한 목적을 위한 긴 예약 (가끔씩 4-6시간)
    if rand(100) < 5 # 5% 확률
      duration = rand(4.0..6.0)
      end_time = start_time + duration.hours
      purpose = ["워크샵", "교육", "전체 회의", "세미나", "해커톤"].sample
    else
      purpose = purposes.sample
    end
    
    # 시간 중복 체크
    existing = RoomReservation.where(
      room: room,
      reservation_date: date
    ).where(
      "(start_time < ? AND end_time > ?) OR (start_time < ? AND end_time > ?)",
      end_time.strftime('%H:%M:%S'), start_time.strftime('%H:%M:%S'),
      start_time.strftime('%H:%M:%S'), end_time.strftime('%H:%M:%S')
    ).exists?
    
    next if existing
    
    begin
      reservation = RoomReservation.create!(
        room: room,
        user: user,
        reservation_date: date,
        start_time: start_time.strftime('%H:%M:%S'),
        end_time: end_time.strftime('%H:%M:%S'),
        purpose: purpose
      )
      created_count += 1
      print "." if created_count % 10 == 0
    rescue => e
      # 중복이나 기타 에러 발생 시 다음으로 넘어감
      next
    end
  end
end

puts "\nCreated #{created_count} sample reservations"

# 통계 출력
puts "\n예약 통계:"
puts "- 전체 예약: #{RoomReservation.count}개"
puts "- 오늘 예약: #{RoomReservation.where(reservation_date: Date.today).count}개"
puts "- 이번 주 예약: #{RoomReservation.where(reservation_date: Date.today.beginning_of_week..Date.today.end_of_week).count}개"

# 회의실별 예약 현황
Room.joins(:room_reservations).group('rooms.name').count.each do |room_name, count|
  puts "- #{room_name}: #{count}개"
end