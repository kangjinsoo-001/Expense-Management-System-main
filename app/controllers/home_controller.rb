class HomeController < ApplicationController
  skip_before_action :require_login, only: [:index]
  
  def index
    if logged_in?
      # 이번 달 내 경비 합계
      current_date = Date.current
      @current_month_sheet = current_user.expense_sheets.find_by(
        year: current_date.year,
        month: current_date.month
      )
      
      if @current_month_sheet
        # 총액
        @total_amount = @current_month_sheet.total_amount || 0
        
        # 각 경비 코드별 금액
        @expenses_by_code = @current_month_sheet.expense_items
                                               .joins(:expense_code)
                                               .group('expense_codes.code', 'expense_codes.name')
                                               .sum(:amount)
      else
        @total_amount = 0
        @expenses_by_code = {}
      end
      
      # 조직장인 경우 경비 통계 메뉴로 유도
      @is_organization_manager = current_user.managed_organizations.any?
      
      # 내가 승인해야 하는 건 리스트 (polymorphic)
      @pending_approvals = ApprovalRequest.for_approver(current_user)
                                         .includes(
                                           approval_line: { approval_line_steps: :approver }
                                         )
                                         .preload(
                                           approvable: [
                                             # ExpenseItem 관련
                                             { expense_sheet: :user }, :expense_code,
                                             # RequestForm 관련
                                             :user, :request_template
                                           ]
                                         )
                                         .where.not(approvable_id: nil)
                                         .order(created_at: :desc)
                                         .limit(10)
      
      # 내가 승인 올린 건들 리스트 (모든 타입)
      expense_requests = ApprovalRequest.where(approvable_type: 'ExpenseItem')
                                        .joins("INNER JOIN expense_items ON expense_items.id = approval_requests.approvable_id")
                                        .joins("INNER JOIN expense_sheets ON expense_sheets.id = expense_items.expense_sheet_id")
                                        .where(expense_sheets: { user_id: current_user.id })
                                        
      form_requests = ApprovalRequest.where(approvable_type: 'RequestForm')
                                     .joins("INNER JOIN request_forms ON request_forms.id = approval_requests.approvable_id")
                                     .where(request_forms: { user_id: current_user.id })
      
      @my_approval_requests = ApprovalRequest.from("(#{expense_requests.to_sql} UNION #{form_requests.to_sql}) AS approval_requests")
                                             .includes(
                                               :approval_histories,
                                               approval_line: { approval_line_steps: :approver }
                                             )
                                             .preload(
                                               approvable: [
                                                 # ExpenseItem 관련
                                                 { expense_sheet: :user }, :expense_code,
                                                 # RequestForm 관련
                                                 :user, :request_template
                                               ]
                                             )
                                             .order(created_at: :desc)
                                             .limit(10)
    end
  end
end
