namespace :expense_sheets do
  desc "승인된 ApprovalRequest를 가진 ExpenseSheet의 상태를 approved로 업데이트"
  task fix_approved_status: :environment do
    puts "승인된 ExpenseSheet 상태 수정 시작..."
    
    # ApprovalRequest가 approved이지만 ExpenseSheet가 submitted인 경우 찾기
    mismatched_sheets = ExpenseSheet.joins(:approval_request)
                                   .where(approval_requests: { status: 'approved' })
                                   .where.not(expense_sheets: { status: 'approved' })
    
    count = 0
    mismatched_sheets.find_each do |sheet|
      # 승인 요청 확인
      approval = sheet.approval_request
      
      if approval&.status == 'approved'
        # 승인 시간 가져오기
        approved_at = approval.approval_histories
                             .where(action: 'approve')
                             .order(created_at: :desc)
                             .first&.approved_at || Time.current
        
        # ExpenseSheet 상태 업데이트
        sheet.update_columns(
          status: 'approved',
          approved_at: approved_at
        )
        
        count += 1
        puts "  - ExpenseSheet ##{sheet.id} (#{sheet.user.name} - #{sheet.year}년 #{sheet.month}월) 상태를 approved로 업데이트"
      end
    end
    
    puts "완료: #{count}개의 ExpenseSheet 상태를 수정했습니다."
  end
  
  desc "반려된 ApprovalRequest를 가진 ExpenseSheet의 상태를 rejected로 업데이트"
  task fix_rejected_status: :environment do
    puts "반려된 ExpenseSheet 상태 수정 시작..."
    
    # ApprovalRequest가 rejected이지만 ExpenseSheet가 submitted인 경우 찾기
    mismatched_sheets = ExpenseSheet.joins(:approval_request)
                                   .where(approval_requests: { status: 'rejected' })
                                   .where(expense_sheets: { status: 'submitted' })
    
    count = 0
    mismatched_sheets.find_each do |sheet|
      # 승인 요청 확인
      approval = sheet.approval_request
      
      if approval&.status == 'rejected'
        # 반려 시간 가져오기
        rejected_at = approval.approval_histories
                             .where(action: 'reject')
                             .order(created_at: :desc)
                             .first&.approved_at || Time.current
        
        # ExpenseSheet 상태 업데이트
        sheet.update_columns(
          status: 'rejected',
          rejected_at: rejected_at
        )
        
        count += 1
        puts "  - ExpenseSheet ##{sheet.id} (#{sheet.user.name} - #{sheet.year}년 #{sheet.month}월) 상태를 rejected로 업데이트"
      end
    end
    
    puts "완료: #{count}개의 ExpenseSheet 상태를 수정했습니다."
  end
  
  desc "모든 불일치 상태 수정 (승인 + 반려)"
  task fix_all_status: :environment do
    Rake::Task['expense_sheets:fix_approved_status'].invoke
    Rake::Task['expense_sheets:fix_rejected_status'].invoke
  end
end