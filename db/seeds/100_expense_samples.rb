# 샘플 경비 데이터 생성
puts "Creating sample expense data..."

# 필요한 데이터 준비
users = User.all.to_a
organizations = Organization.all.to_a
expense_codes = ExpenseCode.all.to_a
cost_centers = CostCenter.all.to_a

puts "  총 #{users.count}명의 사용자에 대한 경비 데이터를 생성합니다..."

# 랜덤 경비 항목 생성을 위한 데이터
vendors = [
  "스타벅스", "투썸플레이스", "이디야커피", "김밥천국", "맥도날드", 
  "서브웨이", "CU편의점", "GS25", "세븐일레븐", "이마트24",
  "카카오택시", "티머니택시", "코레일", "SRT", "대한항공",
  "아시아나항공", "진에어", "알파문구", "모닝글로리", "다이소",
  "교보문고", "예스24", "알라딘", "쿠팡", "네이버페이",
  "한우명가", "육전식당", "놀부부대찌개", "백종원의새마을식당", "BBQ치킨",
  "SK텔레콤", "KT", "LG U+", "이마트", "홈플러스",
  "롯데마트", "코스트코", "하이마트", "전자랜드", "컴퓨존"
]

descriptions = [
  "팀 미팅 음료", "고객 미팅 준비", "야근 식대", "주말 근무 식대", "프로젝트 회의",
  "신규 고객 방문", "정기 미팅 참석", "교육 참석", "세미나 참가", "워크샵 참석",
  "긴급 업무 처리", "본사 방문", "지사 출장", "협력사 미팅", "계약 협의",
  "업무 자료 구매", "참고 도서 구입", "사무용품 구매", "프린터 소모품", "전산 용품",
  "팀 회식", "프로젝트 성공 기념", "신입 환영회", "송별회", "분기 회식",
  "업무 통화료", "데이터 요금", "로밍 요금", "회의실 대관", "주차 요금"
]

# 모든 사용자에게 최근 3개월 경비 시트 생성
user_count = 0
users.each do |user|
  # organization이 없는 사용자는 건너뛰기
  next unless user.organization
  
  user_count += 1
  puts "  [#{user_count}/#{users.count}] #{user.name} (#{user.organization.name})의 경비 데이터 생성 중..."
  
  # 최근 3개월 동안의 경비 시트 생성
  3.times do |month_offset|
    date = month_offset.months.ago
    
    # 이미 존재하는 경비 시트 확인
    existing_sheet = ExpenseSheet.find_by(
      user: user,
      year: date.year,
      month: date.month
    )
    
    sheet = existing_sheet || ExpenseSheet.create!(
      user: user,
      organization: user.organization,
      year: date.year,
      month: date.month,
      status: month_offset == 0 ? "draft" : "approved",
      submitted_at: month_offset == 0 ? nil : date.end_of_month - 5.days,
      approved_at: month_offset == 0 ? nil : date.end_of_month - 3.days,
      approved_by: month_offset == 0 ? nil : user.organization.manager || User.find_by(email: "jaypark@tlx.kr"),
      remarks: "#{date.year}년 #{date.month}월 경비"
    )
    
    # 각 시트에 5개의 랜덤 경비 항목 생성
    items_created = 0
    5.times do |item_index|
      # 랜덤 날짜 (해당 월 내에서)
      random_day = rand(1..date.end_of_month.day)
      expense_date = Date.new(date.year, date.month, random_day)
      
      # 랜덤 경비 코드와 금액
      expense_code = expense_codes.sample
      
      # 사용자 정의 필드 초기화
      custom_fields = {}
      
      # 경비 코드에 따른 금액 범위 설정 (한도 고려)
      amount = case expense_code.code
      when "OTME" # 초과근무 식대 (인당 15,000원)
        # 참석자 수를 먼저 결정
        num_attendees = rand(1..3)
        rand(8000..(15000 * num_attendees))
      when "TRNS" # 교통비
        rand(3500..30000)
      when "CARM" # 차량유지비
        rand(20000..80000)
      when "PHON" # 통신비 (한도 40,000원)
        [30000, 35000, 40000].sample
      when "BOOK" # 도서구입비
        rand(15000..45000)
      when "STAT" # 사무용품
        rand(5000..30000)
      when "DINE" # 회식대 (인당 50,000원)
        # 구성원 수를 먼저 결정
        num_members = rand(2..4)
        rand(30000..(50000 * num_members))
      when "ENTN" # 접대비
        rand(50000..200000)
      when "EQUM" # 기기/비품비
        rand(50000..300000)
      when "PETE" # 잡비
        rand(5000..30000)
      else
        rand(10000..50000)
      end
      
      # required_fields가 Hash인지 확인하고 필드 값 생성
      if expense_code.required_fields.is_a?(Hash)
        expense_code.required_fields.each do |field_key, field_config|
          field_label = field_config['label'] || field_key
          
          # 필드 타입에 따라 적절한 값 생성
          case field_label
          when "참석자"
            # OTME의 경우 이미 계산한 인원수 사용
            if expense_code.code == "OTME" && defined?(num_attendees)
              attendees = users.sample(num_attendees).map(&:name).join(", ")
            else
              num = rand(2..5)
              attendees = users.sample(num).map(&:name).join(", ")
            end
            custom_fields[field_key] = attendees
          when "사유"
            custom_fields[field_key] = descriptions.sample
          when "이동수단"
            custom_fields[field_key] = ["택시", "버스", "지하철", "기차", "자가용", "항공기"].sample
          when "출발지"
            locations = ["본사", "강남역", "서울역", "인천공항", "부산", "대전", "광주", "대구"]
            custom_fields[field_key] = locations.sample
          when "도착지"
            locations = ["본사", "강남역", "서울역", "인천공항", "부산", "대전", "광주", "대구"]
            # 출발지와 다른 곳으로 설정
            departure_key = expense_code.required_fields.keys.find { |k| expense_code.required_fields[k]['label'] == '출발지' }
            custom_fields[field_key] = (locations - [custom_fields[departure_key]]).sample || locations.sample
          when "거리(km)", "거리km"
            custom_fields[field_key] = rand(10..300).to_s
          when "구성원"
            # DINE의 경우 이미 계산한 인원수 사용
            if expense_code.code == "DINE" && defined?(num_members)
              members = users.sample(num_members).map(&:name).join(", ")
            else
              num = rand(3..8)
              members = users.sample(num).map(&:name).join(", ")
            end
            custom_fields[field_key] = members
          when "이동사유"
            custom_fields[field_key] = ["고객 미팅", "프로젝트 회의", "교육 참석", "워크샵", "출장"].sample
          when "사용내용", "품목", "내역"
            custom_fields[field_key] = descriptions.sample
          when "구매목적", "사용목적", "사용처"
            custom_fields[field_key] = ["업무용", "프로젝트용", "팀 공용", "교육용"].sample
          else
            custom_fields[field_key] = "기타 정보"
          end
        end
      end
      
      # 결재선 설정 - 승인 규칙이 있는 경우 필수
      approval_line = nil
      
      # 임시 expense_item 객체로 승인 규칙 확인
      temp_item = sheet.expense_items.build(
        expense_code: expense_code,
        amount: amount,
        expense_date: expense_date
      )
      
      # 승인 규칙이 트리거되는지 확인
      if expense_code.expense_code_approval_rules.active.any? { |rule| rule.evaluate(temp_item) }
        # 사용자가 이미 권한을 가진 경우가 아니라면 결재선 필요
        triggered_rules = expense_code.expense_code_approval_rules.active.select { |rule| rule.evaluate(temp_item) }
        needs_approval = triggered_rules.any? { |rule| !rule.already_satisfied_by_user?(user) }
        
        if needs_approval
          # 기본 결재선 사용
          approval_line = user.approval_lines.find_by(name: "기본")
          # 기본 결재선이 없으면 첫 번째 활성 결재선 사용
          approval_line ||= user.approval_lines.active.first
        end
      elsif rand < 0.3 && month_offset > 0  # 승인 규칙이 없는 경우 30% 확률로 결재선 적용
        approval_line = user.approval_lines.find_by(name: "기본")
      end
      
      begin
        # 시드 데이터 로드 중임을 표시
        ENV['SEEDING'] = 'true'
        
        expense_item = sheet.expense_items.create!(
          expense_code: expense_code,
          cost_center: cost_centers.sample,
          expense_date: expense_date,
          amount: amount,
          description: "#{expense_code.name} - #{descriptions.sample}",
          vendor_name: vendors.sample,
          receipt_number: "RCP#{expense_date.strftime('%Y%m%d')}#{sprintf('%04d', rand(1..9999))}",
          custom_fields: custom_fields,
          approval_line: approval_line
        )
        items_created += 1
      rescue ActiveRecord::RecordInvalid => e
        puts "    ✗ 경비 항목 생성 실패:"
        puts "  사용자: #{user.name} (#{user.email})"
        puts "  경비 코드: #{expense_code.code} - #{expense_code.name}"
        puts "  금액: #{amount}"
        puts "  결재선: #{approval_line&.name || '없음'}"
        puts "  오류: #{e.message}"
        
        # 승인 규칙 정보 출력
        if expense_code.expense_code_approval_rules.active.any?
          puts "  승인 규칙:"
          expense_code.expense_code_approval_rules.active.each do |rule|
            puts "    - #{rule.condition} → #{rule.approver_group.name}"
            puts "      트리거됨: #{rule.evaluate(temp_item)}"
            puts "      사용자 권한 있음: #{rule.already_satisfied_by_user?(user)}"
          end
        end
        
        # 사용자의 결재선 정보
        puts "  사용자의 결재선:"
        user.approval_lines.active.each do |line|
          puts "    - #{line.name}"
        end
        
        raise e
      end
      
      # 결재선이 있고 과거 데이터인 경우, 승인 처리
      if approval_line && month_offset > 0 && expense_item.approval_request
        request = expense_item.approval_request
        
        # 모든 승인 단계 처리
        request.approval_request_steps.ordered.each do |step|
          next unless step.role == 'approve'  # 승인자만 처리
          
          request.approval_histories.create!(
            approver: step.approver,
            step_order: step.step_order,
            role: step.role,
            action: 'approve',
            comment: "확인했습니다.",
            approved_at: expense_date + step.step_order.days
          )
        end
        
        # 승인 완료 처리
        request.update!(
          status: 'approved',
          current_step: request.max_step
        )
      end
    end
  end
end

puts "\n경비 샘플 데이터 생성 완료!"
puts "- 경비 시트: #{ExpenseSheet.count}개"
puts "- 경비 항목: #{ExpenseItem.count}개"
puts "- 승인 요청: #{ApprovalRequest.where(approvable_type: 'ExpenseItem').count}개"
puts "- With approval requests: #{ApprovalRequest.count}"