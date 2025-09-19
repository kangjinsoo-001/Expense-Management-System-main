class MonthlyClosingService
  attr_reader :year, :month, :errors
  
  def initialize(year:, month:)
    @year = year
    @month = month
    @errors = []
  end
  
  def execute
    ActiveRecord::Base.transaction do
      # 1. 승인된 경비 시트 마감 처리
      close_approved_sheets
      
      # 2. 제출되지 않은 경비 시트 확인
      check_unsubmitted_sheets
      
      # 3. 승인 대기 중인 경비 시트 확인
      check_pending_approvals
      
      # 4. 마감 요약 보고서 생성
      summary = generate_closing_summary
      
      
      { success: true, message: "#{year}년 #{month}월 마감 완료", summary: summary }
    end
  rescue => e
    { success: false, message: e.message, errors: @errors }
  end
  
  private
  
  def close_approved_sheets
    sheets = ExpenseSheet.where(year: year, month: month, status: 'approved')
    closed_count = 0
    
    sheets.find_each do |sheet|
      if sheet.close!
        closed_count += 1
        Rails.logger.info "경비 시트 마감: User=#{sheet.user.name}, Sheet=#{sheet.id}"
      else
        @errors << "경비 시트 #{sheet.id} 마감 실패: #{sheet.errors.full_messages.join(', ')}"
      end
    end
    
    Rails.logger.info "총 #{closed_count}개 경비 시트 마감 완료"
  end
  
  def check_unsubmitted_sheets
    # Draft 상태의 경비 시트 확인
    draft_sheets = ExpenseSheet.where(year: year, month: month, status: 'draft')
                               .includes(:user, :organization)
    
    draft_sheets.each do |sheet|
      # 경비 항목이 있는 경우만 알림
      if sheet.expense_items.any?
        Rails.logger.info "미제출 경비 시트: User=#{sheet.user.name}"
      end
    end
  end
  
  def check_pending_approvals
    # 제출되었지만 아직 승인되지 않은 경비 시트
    pending_sheets = ExpenseSheet.where(year: year, month: month, status: 'submitted')
                                 .includes(:user)
    
    # 현재는 승인 기능이 제거되어 있으므로 처리하지 않음
    Rails.logger.info "승인 대기 중인 시트: #{pending_sheets.count}건"
  end
  
  def generate_closing_summary
    all_sheets = ExpenseSheet.where(year: year, month: month)
    
    {
      period: "#{year}년 #{month}월",
      total_sheets: all_sheets.count,
      closed: all_sheets.where(status: 'closed').count,
      approved: all_sheets.where(status: 'approved').count,
      pending_approval: all_sheets.where(status: 'submitted').count,
      draft: all_sheets.where(status: 'draft').count,
      rejected: all_sheets.where(status: 'rejected').count,
      total_amount: all_sheets.sum(:total_amount),
      by_organization: organization_summary,
      by_expense_code: expense_code_summary
    }
  end
  
  def organization_summary
    ExpenseSheet.joins(:organization)
                .where(year: year, month: month)
                .group('organizations.name')
                .sum(:total_amount)
  end
  
  def expense_code_summary
    ExpenseItem.joins(expense_sheet: :expense_code)
               .where(expense_sheets: { year: year, month: month })
               .group('expense_codes.name')
               .sum(:amount)
  end
  
end