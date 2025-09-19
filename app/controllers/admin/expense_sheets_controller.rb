# frozen_string_literal: true

module Admin
  class ExpenseSheetsController < Admin::BaseController
    layout 'admin'

    def index
      # 기본 쿼리 구성 (페이지네이션 없이)
      base_query = ExpenseSheet.includes(:user, :organization).recent
      
      # 첨부파일 개수를 위한 서브쿼리
      attachment_counts = ExpenseAttachment
        .joins(:expense_item)
        .group('expense_items.expense_sheet_id')
        .count
      @attachment_counts = attachment_counts
      
      # 필터링 적용
      if params[:status].present?
        base_query = base_query.where(status: params[:status])
      end
      
      # year_month 파라미터 처리 (새로운 형식)
      if params[:year_month].present?
        begin
          date = Date.parse("#{params[:year_month]}-01")
          base_query = base_query.where(year: date.year, month: date.month)
        rescue ArgumentError
          # 잘못된 날짜 형식인 경우 무시
        end
      elsif params[:year].present? || params[:month].present?
        # 기존 year, month 파라미터 처리 (하위 호환성)
        if params[:year].present?
          base_query = base_query.where(year: params[:year])
        end
        
        if params[:month].present?
          base_query = base_query.where(month: params[:month])
        end
      else
        # 파라미터가 없으면 현재 월로 필터링 (기본값)
        base_query = base_query.where(year: Date.current.year, month: Date.current.month)
      end
      
      if params[:organization_id].present?
        base_query = base_query.where(organization_id: params[:organization_id])
      end
      
      if params[:user_id].present?
        base_query = base_query.where(user_id: params[:user_id])
      end
      
      # 전체 데이터 기준 통계 계산 (페이지네이션 전)
      @stats = {
        total: base_query.count,
        draft: base_query.where(status: 'draft').count,
        submitted: base_query.where(status: 'submitted').count,
        approved: base_query.where(status: 'approved').count,
        rejected: base_query.where(status: 'rejected').count,
        closed: base_query.where(status: 'closed').count
      }
      
      # 페이지네이션 적용 (마지막에)
      @expense_sheets = base_query.page(params[:page]).per(100)
      
      # Turbo Frame 요청 처리
      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def show
      # 경비 시트 레벨 첨부파일 eager loading
      @expense_sheet = ExpenseSheet.with_attached_pdf_attachments.find(params[:id])
      
      # ExpenseSheetAttachment도 로드 (프로덕션 호환성)
      @expense_sheet_attachments = @expense_sheet.expense_sheet_attachments.includes(file_attachment: :blob)
      
      @expense_items = @expense_sheet.expense_items
                                     .not_drafts
                                     .includes(:expense_code)
                                     .with_attached_file
                                     .ordered
      @pdf_analysis_results = @expense_sheet.pdf_analysis_results.includes(:transaction_matches)
      
      # AI 검증 관련 데이터 로드
      @validation_histories = @expense_sheet.validation_histories
      # ValidationHistory에서 full_validation_context 가져오기 (우선)
      # 없으면 Rails 캐시에서 가져오기 (사용자별로 저장되므로 expense_sheet.user.id 사용)
      last_validation_history = @validation_histories.last
      @validation_context = if last_validation_history&.full_validation_context.present?
                             last_validation_history.full_validation_context
                           else
                             Rails.cache.read("validation_context_#{@expense_sheet.id}_#{@expense_sheet.user.id}") || {}
                           end
    end

    def export_all
      # 필터링된 쿼리 구성 (페이지네이션 없이)
      base_query = ExpenseSheet.includes(:user, :organization, expense_items: [:expense_code, :cost_center]).recent
      
      # 필터링 적용
      if params[:status].present?
        base_query = base_query.where(status: params[:status])
      end
      
      # year_month 파라미터 처리 (새로운 형식)
      if params[:year_month].present?
        begin
          date = Date.parse("#{params[:year_month]}-01")
          base_query = base_query.where(year: date.year, month: date.month)
        rescue ArgumentError
          # 잘못된 날짜 형식인 경우 무시
        end
      elsif params[:year].present? || params[:month].present?
        # 기존 year, month 파라미터 처리 (하위 호환성)
        if params[:year].present?
          base_query = base_query.where(year: params[:year])
        end
        
        if params[:month].present?
          base_query = base_query.where(month: params[:month])
        end
      end
      
      if params[:organization_id].present?
        base_query = base_query.where(organization_id: params[:organization_id])
      end
      
      if params[:user_id].present?
        base_query = base_query.where(user_id: params[:user_id])
      end
      
      # 사용자별로 그룹화
      @expense_sheets_by_user = base_query.group_by(&:user)
      
      respond_to do |format|
        format.xlsx {
          # 파일명 생성 - 필터링된 연월 포함
          period = if params[:year].present? && params[:month].present?
            "#{params[:year]}-#{params[:month].to_s.rjust(2, '0')}"
          elsif params[:year].present?
            params[:year]
          else
            "all"
          end
          
          timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
          filename = "expense_all_#{period}_#{timestamp}.xlsx"
          
          response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
        }
      end
    end

    private
  end
end