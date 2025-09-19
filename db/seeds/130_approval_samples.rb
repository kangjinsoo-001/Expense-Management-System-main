# 007_approval_sample_data.rb
# 결재선이 적용된 경비 항목 및 승인 요청 샘플 데이터

puts "=== 결재선 적용 샘플 데이터 생성 시작 ==="

# 참조 데이터
users = User.all.to_a
employees = users.select { |u| u.employee? }
managers = users.select { |u| u.manager? }
expense_sheets = ExpenseSheet.all.to_a
approval_lines = ApprovalLine.all.to_a

# 1. 승인 대기 중인 경비 항목들
if employees.any? && approval_lines.any?
  # 첫 번째 직원의 경비 시트에 결재선 적용
  employee = employees.first
  sheet = expense_sheets.find { |s| s.user == employee } || ExpenseSheet.create!(
    user: employee,
    year: Date.current.year,
    month: Date.current.month
  )
  
  # 기본 결재선 적용된 항목
  basic_line = approval_lines.find { |l| l.name == "기본 결재선" && l.user == employee }
  if basic_line
    expense_item1 = sheet.expense_items.create!(
      expense_date: Date.current.beginning_of_month + 10.days,
      expense_code: ExpenseCode.find_by(code: 'TRNS') || ExpenseCode.first,
      cost_center: CostCenter.first,
      description: '고객사 방문 택시비',
      amount: 28000,  # 2명 * 15,000원 이하로 조정
      approval_line: basic_line,
      custom_fields: {
        '이동수단' => '택시',
        '출발지' => '본사',
        '도착지' => '고객사',
        '이동사유' => '고객사 미팅 참석'
      }
    )
    puts "- 승인 대기 경비 항목 생성: #{expense_item1.description}"
  end
  
  # 2단계 결재선 적용된 항목
  two_step_line = approval_lines.find { |l| l.name == "2단계 결재선" }
  if two_step_line && employees.second
    sheet2 = expense_sheets.find { |s| s.user == employees.second } || ExpenseSheet.create!(
      user: employees.second,
      year: Date.current.year,
      month: Date.current.month
    )
    
    expense_item2 = sheet2.expense_items.create!(
      expense_date: Date.current.beginning_of_month + 12.days,
      expense_code: ExpenseCode.find_by(code: 'TRNS') || ExpenseCode.first,
      cost_center: CostCenter.first,
      description: '부산 출장 KTX 왕복',
      amount: 120000,
      approval_line: two_step_line,
      custom_fields: {
        '이동수단' => '기차',
        '출발지' => '서울역',
        '도착지' => '부산역',
        '이동사유' => '신규 고객사 미팅'
      }
    )
    puts "- 2단계 승인 경비 항목 생성: #{expense_item2.description}"
  end
end

# 2. 부분 승인된 경비 항목 (2단계 중 1단계 완료)
if managers.count >= 2 && employees.third
  sheet3 = expense_sheets.find { |s| s.user == employees.third } || ExpenseSheet.create!(
    user: employees.third,
    year: Date.current.year,
    month: Date.current.month
  )
  
  parallel_line = approval_lines.find { |l| l.name == "병렬 승인 결재선" }
  if parallel_line
    expense_item3 = sheet3.expense_items.create!(
      expense_date: Date.current.beginning_of_month + 8.days,
      expense_code: ExpenseCode.find_by(code: 'DINE') || ExpenseCode.first,
      cost_center: CostCenter.first,
      description: '팀 회식비 (1차 승인 완료)',
      amount: 180000,  # 4명 * 50,000원 이하
      approval_line: parallel_line,
      custom_fields: {
        '구성원' => '김철수, 이영희, 박민수, 최지현',
        '사유' => '분기 목표 달성 회식'
      }
    )
    
    # 첫 번째 승인자가 이미 승인한 것으로 설정
    if expense_item3.approval_request
      request = expense_item3.approval_request
      first_approver = request.current_step_approvers.first.approver
      
      request.approval_histories.create!(
        approver: first_approver,
        step_order: 1,
        role: 'approve',
        action: 'approve',
        comment: '확인했습니다. 승인합니다.',
        approved_at: 1.day.ago
      )
      
      puts "- 부분 승인된 경비 항목 생성: #{expense_item3.description}"
    end
  end
end

# 3. 승인 완료된 경비 항목
if managers.any? && employees.any?
  employee = employees.sample
  # 이전 달 시트 찾기
  prev_year = (Date.current - 1.month).year
  prev_month = (Date.current - 1.month).month
  completed_sheet = employee.expense_sheets.find_by(year: prev_year, month: prev_month) || 
                    ExpenseSheet.create!(
                      user: employee,
                      year: prev_year,
                      month: prev_month
                    )
  
  basic_line = approval_lines.find { |l| l.user == employee && l.approval_line_steps.count == 1 }
  if basic_line
    completed_item = completed_sheet.expense_items.create!(
      expense_date: (Date.current - 1.month).beginning_of_month + 15.days,
      expense_code: ExpenseCode.find_by(code: 'STAT') || ExpenseCode.first,
      cost_center: CostCenter.first,
      description: '프린터 토너 구매',
      amount: 85000,
      approval_line: basic_line,
      custom_fields: {
        '품목' => 'HP LaserJet 토너 검정 2개',
        '구매목적' => '사무실 프린터 소모품 보충'
      }
    )
    
    # 승인 완료 처리
    if completed_item.approval_request
      request = completed_item.approval_request
      approver = request.current_step_approvers.first.approver
      
      request.approval_histories.create!(
        approver: approver,
        step_order: 1,
        role: 'approve',
        action: 'approve',
        comment: '확인 완료. 승인합니다.',
        approved_at: 1.week.ago
      )
      
      request.update!(
        status: 'approved',
        current_step: request.max_step
      )
      
      puts "- 승인 완료된 경비 항목 생성: #{completed_item.description}"
    end
  end
end

# 4. 반려된 경비 항목
if managers.any? && employees.last
  rejected_sheet = employees.last.expense_sheets.find_by(year: Date.current.year, month: Date.current.month) ||
                   ExpenseSheet.create!(
                     user: employees.last,
                     year: Date.current.year,
                     month: Date.current.month
                   )
  
  basic_line = approval_lines.find { |l| l.user == employees.last }
  if basic_line
    rejected_item = rejected_sheet.expense_items.create!(
      expense_date: Date.current.beginning_of_month + 5.days,
      expense_code: ExpenseCode.find_by(code: 'ENTN') || ExpenseCode.first,
      cost_center: CostCenter.first,
      description: '고객 접대비 (영수증 미첨부)',
      amount: 180000,
      approval_line: basic_line,
      custom_fields: {
        '참석자' => '김철수, 이영희, (주)테크솔루션 박대표, 최과장',
        '사유' => '계약 갱신 협의를 위한 비즈니스 미팅'
      }
    )
    
    # 반려 처리
    if rejected_item.approval_request
      request = rejected_item.approval_request
      approver = request.current_step_approvers.first.approver
      
      request.approval_histories.create!(
        approver: approver,
        step_order: 1,
        role: 'approve',
        action: 'reject',
        comment: '영수증이 첨부되지 않았습니다. 영수증 첨부 후 재신청 바랍니다.',
        approved_at: 2.days.ago
      )
      
      request.update!(status: 'rejected')
      
      puts "- 반려된 경비 항목 생성: #{rejected_item.description}"
    end
  end
end

# 5. 참조자가 있는 승인 진행 중 항목
if approval_lines.any?
  ref_line = approval_lines.find { |l| l.name == "참조자 포함 결재선" }
  if ref_line && ref_line.user
    ref_sheet = ref_line.user.expense_sheets.find_by(year: Date.current.year, month: Date.current.month) ||
                ExpenseSheet.create!(
                  user: ref_line.user,
                  year: Date.current.year,
                  month: Date.current.month
                )
    
    ref_item = ref_sheet.expense_items.create!(
      expense_date: Date.current.beginning_of_month + 14.days,
      expense_code: ExpenseCode.find_by(code: 'DINE') || ExpenseCode.first,
      cost_center: CostCenter.first,
      description: '프로젝트 킥오프 미팅 회식',
      amount: 95000,
      approval_line: ref_line,
      custom_fields: {
        '구성원' => '김과장, 이대리, 박사원, 최주임',
        '사유' => '신규 프로젝트 착수 기념 회식'
      }
    )
    
    # 참조자가 열람한 기록 추가
    if ref_item.approval_request
      request = ref_item.approval_request
      referrer = request.approval_line.approval_line_steps.referrers.first&.approver
      
      if referrer
        request.approval_histories.create!(
          approver: referrer,
          step_order: 1,
          role: 'reference',
          action: 'view',
          approved_at: 1.hour.ago
        )
      end
      
      puts "- 참조자 포함 경비 항목 생성: #{ref_item.description}"
    end
  end
end

puts "=== 결재선 적용 샘플 데이터 생성 완료 ==="
puts "- 총 #{ApprovalRequest.count}개의 승인 요청 생성"
puts "- 총 #{ApprovalHistory.count}개의 승인 이력 생성"
puts "- 승인 대기: #{ApprovalRequest.in_progress.count}건"
puts "- 승인 완료: #{ApprovalRequest.where(status: 'approved').count}건"
puts "- 반려: #{ApprovalRequest.where(status: 'rejected').count}건"