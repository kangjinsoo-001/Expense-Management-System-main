# 성능 테스트용 대량 경비 데이터 생성
# 2024년 1월 ~ 2025년 6월 (18개월)
# 월 평균 10만 건의 경비 항목 생성

# ==========================================
# 안전 장치: 개발 환경에서만 실행 가능
# ==========================================
unless Rails.env.development?
  puts "\n" + "!"*60
  puts "경고: 대량 성능 테스트 데이터는 개발 환경에서만 실행 가능합니다!"
  puts "현재 환경: #{Rails.env}"
  puts "이 시드는 프로덕션 환경에서 실행되지 않도록 차단되었습니다."
  puts "!"*60
  exit
end

# 추가 안전 장치: 환경 변수 확인
if ENV['ALLOW_PERFORMANCE_SEED'] != 'true'
  puts "\n" + "="*60
  puts "성능 테스트 데이터 생성 스킵됨"
  puts "대량 데이터를 생성하려면 다음 명령을 사용하세요:"
  puts "ALLOW_PERFORMANCE_SEED=true rails db:seed"
  puts "="*60
  exit
end

puts "\n" + "="*60
puts "성능 테스트용 대량 경비 데이터 생성 시작"
puts "기간: 2024년 1월 ~ 2025년 6월 (18개월)"
puts "목표: 월별 11만~13만 건 (변동성 포함), 총 약 200만 건 이상"
puts "모든 사용자 최소 10건 이상 경비 보유"
puts "="*60

# 필요한 데이터 로드
users = User.all.to_a
expense_codes = ExpenseCode.active.to_a
cost_centers = CostCenter.active.to_a
organizations = Organization.all.to_a

if users.empty? || expense_codes.empty? || cost_centers.empty?
  puts "경고: 필요한 기본 데이터가 없습니다. 다른 시드를 먼저 실행하세요."
  exit
end

puts "\n사용 가능한 데이터:"
puts "  - 사용자: #{users.count}명"
puts "  - 경비 코드: #{expense_codes.count}개"
puts "  - 코스트 센터: #{cost_centers.count}개"

# 경비 코드별 가중치 설정 - 월별로 랜덤하게 변경
def get_random_weights
  base_weights = {
    'OTME' => rand(10..30),  # 초과근무 식대
    'TRNS' => rand(10..30),  # 교통비
    'CARM' => rand(5..20),   # 차량유지비
    'STAT' => rand(5..15),   # 사무용품/소모품비
    'BOOK' => rand(1..10),   # 도서인쇄비
    'DINE' => rand(1..15),   # 회식비
    'ENTN' => rand(1..10),   # 접대비
    'EQUM' => rand(1..10),   # 기기/비품비
    'PHON' => rand(5..15),   # 통신비
    'PETE' => rand(1..10)    # 잡비
  }
  base_weights
end

expense_code_weights = get_random_weights

# 경비 코드별 금액 범위 - 더 랜덤하게
def get_random_amount(code)
  case code
  when 'OTME' then rand(8000..60000)      # 초과근무 식대
  when 'TRNS' then rand(2000..80000)      # 교통비
  when 'CARM' then rand(5000..150000)     # 차량유지비
  when 'STAT' then rand(3000..70000)      # 사무용품
  when 'BOOK' then rand(8000..150000)     # 도서
  when 'DINE' then rand(50000..800000)    # 회식비
  when 'ENTN' then rand(50000..1500000)   # 접대비
  when 'EQUM' then rand(30000..5000000)   # 기기/비품
  when 'PHON' then rand(20000..80000)     # 통신비
  when 'PETE' then rand(3000..50000)      # 잡비
  else rand(10000..100000)
  end
end

# 더미 설명 템플릿
description_templates = {
  'OTME' => ['야근식대 (5명)_프로젝트 개발', '야근식대 (3명)_시스템 점검', '야근식대 (4명)_긴급 대응'],
  'TRNS' => ['택시 (강남역→판교역)_고객 미팅', '버스 (서울→대전)_출장', '지하철 (강남→여의도)_회의 참석'],
  'CARM' => ['주차비_고객사 방문', '통행료_지방 출장', '주유비_업무용 차량'],
  'STAT' => ['노트북 거치대_업무용', '프린터 토너_사무실', 'A4 용지_부서 공용'],
  'BOOK' => ['클린코드_개발 역량 향상', '프로젝트 관리_PM 스킬', '디자인 패턴_기술 학습'],
  'DINE' => ['회식 (개발팀 10명)_프로젝트 완료', '회식 (영업팀 8명)_분기 마감', '회식 (전체 15명)_송년회'],
  'ENTN' => ['접대비 (삼성전자)_계약 협의', '접대비 (LG화학)_프로젝트 논의', '접대비 (현대차)_신규 제안'],
  'EQUM' => ['모니터_개발 환경', '키보드/마우스_업무용', '노트북_신규 직원'],
  'PHON' => ['통신비_11월분', '통신비_12월분', '통신비_업무용 휴대폰'],
  'PETE' => ['커피/다과_회의용', '명함 제작_신규', '사무용품_기타']
}

# 가중치 기반 경비 코드 선택 함수
def weighted_sample(expense_codes, weights)
  weighted_codes = []
  expense_codes.each do |code|
    weight = weights[code.code] || 1
    weight.times { weighted_codes << code }
  end
  weighted_codes.sample
end

# 평일 날짜 생성 함수
def random_weekday(year, month)
  date = nil
  loop do
    day = rand(1..28)  # 월말 처리 단순화를 위해 28일까지만
    date = Date.new(year, month, day)
    break unless date.saturday? || date.sunday?
  end
  date
end

# 통계 변수 초기화
total_sheets_created = 0
total_items_created = 0
start_time = Time.current

# 배치 크기 설정
BATCH_SIZE = 10000

# 메인 처리 루프
(2024..2025).each do |year|
  months = year == 2025 ? (1..6) : (1..12)
  
  months.each do |month|
    month_start_time = Time.current
    month_sheets = 0
    month_items = 0
    
    # 매월 경비 코드 가중치를 랜덤하게 변경
    expense_code_weights = get_random_weights
    
    # 월별 특성 반영 (연말, 분기말 증가)
    month_multiplier = case month
                      when 3, 6, 9 then 1.2  # 분기말
                      when 12 then 1.5        # 연말
                      else 1.0
                      end
    
    # 월별 목표를 11만~13만 사이로 랜덤 설정 (변동성 추가)
    target_items_for_month = (rand(110_000..130_000) * month_multiplier).to_i
    base_items_per_user = target_items_for_month / users.count
    
    puts "\n#{year}년 #{month}월 데이터 생성 중..."
    puts "  목표: #{target_items_for_month.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}건"
    puts "  사용자당 평균: #{base_items_per_user}건"
    
    # 1. 경비 시트 생성 (각 사용자당 1개)
    expense_sheets_data = []
    users.each do |user|
      expense_sheets_data << {
        user_id: user.id,
        organization_id: user.organization_id || organizations.sample.id,
        year: year,
        month: month,
        status: ['draft', 'submitted', 'approved'].sample,
        total_amount: 0,  # 나중에 업데이트
        created_at: Time.current,
        updated_at: Time.current,
        validation_status: 'validated'
      }
    end
    
    # 경비 시트 배치 삽입 - returning을 사용하지 않고 직접 조회
    ExpenseSheet.insert_all(expense_sheets_data)
    
    # 방금 생성한 경비 시트들을 조회하여 매핑
    sheet_id_map = {}
    ExpenseSheet.where(year: year, month: month).each do |sheet|
      sheet_id_map[sheet.user_id] = sheet.id
    end
    month_sheets = sheet_id_map.size
    
    # 2. 경비 항목 생성
    expense_items_data = []
    sheet_totals = Hash.new(0)
    actual_items_created = 0  # 실제 생성된 항목 수 추적
    
    users.each_with_index do |user, index|
      # 모든 사용자가 최소 10건 이상 경비 보유
      # 변동성 적용 (±40%, 최소 10건 보장)
      variation = rand(0.6..1.4)
      items_count = [(base_items_per_user * variation).to_i, 10].max
      
      # 목표 달성을 위한 조정 (마지막 사용자들에게 추가 할당)
      if index >= users.count - 10  # 마지막 10명
        remaining_items = target_items_for_month - actual_items_created
        remaining_users = users.count - index
        if remaining_items > remaining_users * 10  # 목표 달성 필요
          items_count = [(remaining_items / remaining_users.to_f).to_i, items_count].max
        end
      end
      sheet_id = sheet_id_map[user.id]
      
      items_count.times do
        expense_code = weighted_sample(expense_codes, expense_code_weights)
        amount = get_random_amount(expense_code.code)
        
        expense_items_data << {
          expense_sheet_id: sheet_id,
          expense_code_id: expense_code.id,
          expense_date: random_weekday(year, month),
          amount: amount,
          description: description_templates[expense_code.code]&.sample || "경비 항목",
          cost_center_id: cost_centers.sample.id,
          is_valid: true,
          is_draft: false,
          validation_status: 'validated',
          created_at: Time.current,
          updated_at: Time.current
        }
        
        sheet_totals[sheet_id] += amount
        actual_items_created += 1
        
        # 배치 크기에 도달하면 삽입
        if expense_items_data.size >= BATCH_SIZE
          ExpenseItem.insert_all(expense_items_data)
          month_items += expense_items_data.size
          print "."
          expense_items_data = []
        end
      end
    end
    
    # 남은 항목 삽입
    if expense_items_data.any?
      ExpenseItem.insert_all(expense_items_data)
      month_items += expense_items_data.size
    end
    
    # 3. 경비 시트 총액 업데이트
    sheet_totals.each do |sheet_id, total|
      ExpenseSheet.where(id: sheet_id).update_all(total_amount: total)
    end
    
    # 월별 통계 출력
    month_elapsed = Time.current - month_start_time
    total_sheets_created += month_sheets
    total_items_created += month_items
    
    puts "\n  ✓ #{year}년 #{month}월 완료"
    puts "    - 경비 시트: #{month_sheets}개"
    puts "    - 경비 항목: #{month_items.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}건"
    puts "    - 목표 대비: #{(month_items.to_f / target_items_for_month * 100).round(1)}%"
    puts "    - 소요 시간: #{month_elapsed.round(1)}초"
    
    # 가비지 컬렉션 실행 (메모리 관리)
    GC.start if month % 3 == 0
  end
end

# 최종 통계
total_elapsed = Time.current - start_time
puts "\n" + "="*60
puts "성능 테스트용 대량 경비 데이터 생성 완료!"
puts "="*60
puts "생성 결과:"
puts "  - 총 경비 시트: #{total_sheets_created.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}개"
puts "  - 총 경비 항목: #{total_items_created.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}건"
puts "  - 월 평균: #{(total_items_created / 18.0).round.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}건"
puts "  - 총 소요 시간: #{(total_elapsed / 60).round(1)}분"
puts "\n데이터베이스 현황:"
puts "  - ExpenseSheet: #{ExpenseSheet.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}개"
puts "  - ExpenseItem: #{ExpenseItem.count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}개"