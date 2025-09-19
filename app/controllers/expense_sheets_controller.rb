class ExpenseSheetsController < ApplicationController
  include HttpCaching
  include TurboCacheControl
  
  before_action :require_login
  before_action :set_expense_sheet, only: [:show, :edit, :update, :destroy, :confirm_submit, :validate_items, :attach_pdf, :delete_pdf_attachment, :export, :validate_sheet, :validate_all_items, :validate_with_ai, :validate_step, :validation_history]

  def list
    # 월별 경비 시트 리스트
    @expense_sheets = current_user.expense_sheets
                                  .order(year: :desc, month: :desc)
                                  .page(params[:page])
  end
  
  def index
    # 로컬 개발 환경에서의 캐싱 문제 방지
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    
    # 날짜 파라미터가 없는 경우 가장 최근 추가한 경비 항목의 월로 리다이렉트
    if params[:year].blank? && params[:month].blank?
      # 가장 최근에 추가한 경비 항목 찾기
      latest_sheet = current_user.expense_sheets
                                 .joins(:expense_items)
                                 .where(expense_items: { is_draft: false })
                                 .order('expense_items.created_at DESC')
                                 .first
      
      if latest_sheet
        # 해당 월로 리다이렉트
        redirect_to expense_sheets_path(year: latest_sheet.year, month: latest_sheet.month)
        return
      else
        # 경비 항목이 없으면 현재 월로
        @year = Date.current.year
        @month = Date.current.month
      end
    else
      # 날짜 파라미터가 있는 경우
      @year = params[:year].to_i
      @month = params[:month].to_i
    end
    
    # 유효한 날짜인지 확인
    begin
      @current_date = Date.new(@year, @month, 1)
    rescue ArgumentError
      @current_date = Date.current
      @year = @current_date.year
      @month = @current_date.month
    end
    
    # 이전/다음 달 계산
    @prev_date = @current_date.prev_month
    @next_date = @current_date.next_month
    
    # 해당 월의 경비 시트 조회
    @expense_sheet = current_user.expense_sheets
                                .find_by(year: @year, month: @month)
    
    # expense_sheet가 있을 때만 expense_items를 별도로 로드 - position으로 정렬
    if @expense_sheet
      # WAL 모드에서 최신 데이터를 보장하기 위해 (개발 환경)
      if Rails.env.development?
        ActiveRecord::Base.connection_pool.clear_reloadable_connections!
        ActiveRecord::Base.connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
      end
      
      @expense_items = @expense_sheet.expense_items
                                     .where(is_draft: false)
                                     .includes(
                                       :expense_code,
                                       approval_request: [
                                         { approval_histories: :approver },
                                         { approval_line: { approval_line_steps: :approver } }
                                       ]
                                     )
                                     .ordered  # position 순으로 정렬
      
      # PDF 분석 결과 로드 (show에서 이동)
      @pdf_analysis_results = @expense_sheet.pdf_analysis_results.includes(:transaction_matches)
      
      # 최신 검증 이력 가져오기
      @latest_validation = @expense_sheet.validation_histories.recent.first
      
      # 첨부서류 관련 데이터 (제출하기 섹션용)
      @sheet_attachments = @expense_sheet.expense_sheet_attachments.includes(:attachment_requirement)
      @required_attachments = AttachmentRequirement.where(
        attachment_type: 'expense_sheet',
        required: true,
        active: true
      ).order(:position)
      @uploaded_requirement_ids = @sheet_attachments.pluck(:attachment_requirement_id).compact
      
      # 결재선 검증을 위한 데이터
      @approval_lines_data = prepare_approval_lines_data
      @expense_sheet_rules_data = prepare_expense_sheet_rules_data
      @current_user_groups_data = prepare_current_user_groups_data
    end
    
    # 현재 로그인 사용자 명시적 확인
    Rails.logger.debug "Current user: #{current_user.email} (ID: #{current_user.id})"
    Rails.logger.debug "Viewing expense sheet for: #{@year}-#{@month}"
  end


  def new
    year = params[:year].present? ? params[:year].to_i : Date.current.year
    month = params[:month].present? ? params[:month].to_i : Date.current.month
    
    @expense_sheet = current_user.expense_sheets.build(
      organization: current_user.organization,
      year: year,
      month: month
    )
  end

  def create
    @expense_sheet = current_user.expense_sheets.build(expense_sheet_params)
    @expense_sheet.organization = current_user.organization

    if @expense_sheet.save
      # 생성된 경비 시트의 년월로 리다이렉트
      redirect_with_turbo_reload expense_sheets_path(year: @expense_sheet.year, month: @expense_sheet.month), 
                                 notice: '경비 시트가 생성되었습니다.', 
                                 status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # 경비 시트 상세 보기
    @expense_items = @expense_sheet.expense_items
                                   .not_drafts
                                   .includes(:expense_code, :cost_center)
                                   .with_attached_file
                                   .ordered
    
    # AI 검증 관련 데이터
    @validation_histories = @expense_sheet.validation_histories
    last_validation_history = @validation_histories.last
    @validation_context = if last_validation_history&.full_validation_context.present?
                           last_validation_history.full_validation_context
                         else
                           Rails.cache.read("validation_context_#{@expense_sheet.id}_#{@expense_sheet.user.id}") || {}
                         end
    
    # 승인 관련 정보
    @approval_line = @expense_sheet.approval_line
    @approvals = @approval_line&.approvals&.includes(:approver) || []
  end

  def edit
    unless @expense_sheet.editable?
      redirect_to expense_sheets_path, alert: '수정할 수 없는 상태입니다.'
    end
  end

  def sort_items
    @expense_sheet = current_user.expense_sheets.find(params[:id])
    
    if @expense_sheet.editable?
      ExpenseItem.update_positions(@expense_sheet.id, params[:item_ids])
      render json: { success: true }
    else
      render json: { success: false, error: '편집할 수 없는 상태입니다.' }, status: :unprocessable_entity
    end
  end
  
  def bulk_sort_items
    @expense_sheet = current_user.expense_sheets.find(params[:id])
    
    if @expense_sheet.editable?
      sort_by = params[:sort_by]
      
      items = case sort_by
      when 'date'
        @expense_sheet.expense_items.by_date
      when 'date_desc'
        @expense_sheet.expense_items.by_date_desc
      when 'amount'
        @expense_sheet.expense_items.by_amount
      when 'amount_desc'
        @expense_sheet.expense_items.by_amount_desc
      when 'creation'
        @expense_sheet.expense_items.by_creation
      when 'creation_desc'
        @expense_sheet.expense_items.by_creation_desc
      when 'expense_code'
        @expense_sheet.expense_items.by_expense_code_order
      else
        @expense_sheet.expense_items.ordered
      end
      
      # 새로운 순서로 position 업데이트
      ExpenseItem.update_positions(@expense_sheet.id, items.pluck(:id))
      
      respond_to do |format|
        format.json { render json: { success: true, message: '정렬이 완료되었습니다.' } }
        format.html do
          # 현재 페이지에 따라 리다이렉트
          if request.referer&.include?('expense_sheets') && !request.referer&.include?("/expense_sheets/#{@expense_sheet.id}")
            # index 페이지에서 온 경우
            redirect_to expense_sheets_path(year: @expense_sheet.year, month: @expense_sheet.month), notice: '정렬이 완료되었습니다.'
          else
            # show 페이지에서 온 경우 (이제는 index로 리다이렉트)
            redirect_to expense_sheets_path(year: @expense_sheet.year, month: @expense_sheet.month), notice: '정렬이 완료되었습니다.'
          end
        end
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, error: '편집할 수 없는 상태입니다.' }, status: :unprocessable_entity }
        format.html do
          if request.referer&.include?('expense_sheets') && !request.referer&.include?("/expense_sheets/#{@expense_sheet.id}")
            redirect_to expense_sheets_path(year: @expense_sheet.year, month: @expense_sheet.month), alert: '편집할 수 없는 상태입니다.'
          else
            redirect_to expense_sheets_path(year: @expense_sheet.year, month: @expense_sheet.month), alert: '편집할 수 없는 상태입니다.'
          end
        end
      end
    end
  end

  def update
    unless @expense_sheet.editable?
      redirect_to expense_sheets_path, alert: '수정할 수 없는 상태입니다.'
      return
    end

    if @expense_sheet.update(expense_sheet_params)
      # 수정된 경비 시트의 년월로 리다이렉트
      redirect_with_turbo_reload expense_sheets_path(year: @expense_sheet.year, month: @expense_sheet.month), 
                                 notice: '경비 시트가 수정되었습니다.', 
                                 status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @expense_sheet.editable?
      @expense_sheet.destroy
      redirect_to expense_sheets_path, notice: '경비 시트가 삭제되었습니다.'
    else
      redirect_to expense_sheets_path, alert: '삭제할 수 없는 상태입니다.'
    end
  end

  def confirm_submit
    # 실제 제출 처리
    unless @expense_sheet.submittable?
      redirect_to expense_sheets_path, alert: '제출할 수 없는 상태입니다.'
      return
    end
    
    # 제출 전 검증
    @expense_sheet.validate_all_items
    
    if @expense_sheet.has_invalid_items?
      flash[:alert] = "검증되지 않은 경비 항목이 #{@expense_sheet.invalid_items_count}개 있습니다. 경비 항목을 다시 확인해주세요."
      return redirect_to expense_sheets_path
    end

    if @expense_sheet.expense_items.empty?
      flash[:alert] = "경비 항목이 없습니다. 최소 1개 이상의 경비 항목을 추가해주세요."
      return redirect_to expense_sheets_path
    end
    
    # 필수 첨부파일 검증 (AJAX 업로드 방식이므로 이미 업로드된 파일 확인)
    required_attachments = AttachmentRequirement.where(
      attachment_type: 'expense_sheet',
      required: true,
      active: true
    )
    
    if required_attachments.any?
      uploaded_requirement_ids = @expense_sheet.expense_sheet_attachments.pluck(:attachment_requirement_id).compact
      missing_requirements = required_attachments.where.not(id: uploaded_requirement_ids)
      
      if missing_requirements.any?
        missing_names = missing_requirements.pluck(:name).join(', ')
        flash[:alert] = "필수 첨부 서류가 누락되었습니다: #{missing_names}"
        return redirect_to expense_sheets_path
      end
    end
    
    # 기존 PDF 첨부 파일 처리 (하위 호환성)
    if params[:expense_sheet] && params[:expense_sheet][:pdf_attachments].present?
      invalid_files = attach_pdf_files(params[:expense_sheet][:pdf_attachments])
      if invalid_files.any?
        flash[:alert] = "첨부 파일 처리 중 오류가 발생했습니다: #{invalid_files.join(', ')}"
        return redirect_to expense_sheets_path
      end
    end
    
    # 트랜잭션으로 제출 처리
    ActiveRecord::Base.transaction do
      # 첨부 파일이 업로드된 경우 PDF 분석 수행
      if @expense_sheet.pdf_attachments.any?
        analyze_pdf_attachments
      end
      
      # 결재선 설정
      approval_line_id = params[:expense_sheet][:approval_line_id] if params[:expense_sheet]
      approval_line_id ||= params[:approval_line_id]
      
      if approval_line_id.present?
        @expense_sheet.approval_line_id = approval_line_id
        unless @expense_sheet.save
          flash[:alert] = @expense_sheet.errors.full_messages.join(', ')
          return redirect_to expense_sheets_path
        end
      elsif @expense_sheet.approval_line_id.blank?
        flash[:alert] = "결재선을 선택해주세요."
        return redirect_to expense_sheets_path
      end
      
      # 경비 시트 제출
      if @expense_sheet.submit!(current_user)
        
        # 실시간 대시보드 업데이트 (백그라운드 Job으로 처리)
        DashboardUpdateJob.perform_later('expense_sheet_update', @expense_sheet.id) if defined?(DashboardUpdateJob)
        
        redirect_with_turbo_reload expense_sheets_path, notice: '경비 시트가 성공적으로 제출되었습니다.', status: :see_other
      else
        redirect_to expense_sheets_path, alert: @expense_sheet.errors.full_messages.join(', ')
      end
    end
  rescue => e
    Rails.logger.error "경비 시트 제출 중 오류: #{e.message}"
    redirect_to expense_sheets_path, alert: "제출 중 오류가 발생했습니다: #{e.message}"
  end

  def validate_items
    @expense_sheet.validate_all_items
    
    respond_to do |format|
      format.json {
        render json: {
          valid_count: @expense_sheet.valid_items_count,
          invalid_count: @expense_sheet.invalid_items_count,
          total_count: @expense_sheet.expense_items.count,
          all_valid: !@expense_sheet.has_invalid_items?
        }
      }
    end
  end

  def attach_pdf
    unless @expense_sheet.editable?
      redirect_to expense_sheets_path, alert: 'PDF를 첨부할 수 없는 상태입니다.'
      return
    end

    if params[:expense_sheet][:pdf_attachments].present?
      # 파일 크기 및 형식 검증
      max_file_size = 10.megabytes
      invalid_files = []
      
      params[:expense_sheet][:pdf_attachments].each do |file|
        if file.size > max_file_size
          invalid_files << "#{file.original_filename}: 파일 크기가 10MB를 초과합니다"
        elsif file.content_type != 'application/pdf'
          invalid_files << "#{file.original_filename}: PDF 파일만 업로드 가능합니다"
        end
      end
      
      if invalid_files.any?
        redirect_to expense_sheets_path, alert: invalid_files.join(', ')
        return
      end
      
      attached_files = @expense_sheet.pdf_attachments.attach(params[:expense_sheet][:pdf_attachments])
      
      # attach 메서드는 배열을 반환하지 않을 수 있으므로 reload
      @expense_sheet.reload
      
      # 각 첨부 파일에 대해 PDF 분석 수행
      analysis_service = PdfAnalysisService.new
      analysis_errors = []
      successful_analyses = 0
      
      # 방금 첨부된 파일들만 처리 (분석되지 않은 것들)
      analyzed_attachment_ids = @expense_sheet.pdf_analysis_results.pluck(:attachment_id)
      @expense_sheet.pdf_attachments.each do |attachment|
        next if analyzed_attachment_ids.include?(attachment.id.to_s)
        
        # PDF 파일인 경우에만 분석
        if attachment.blob.content_type == 'application/pdf'
          begin
            # 전체 분석 수행 (텍스트 추출, 거래 파싱, 매칭)
            attachment.blob.open do |file|
              result = analysis_service.analyze_and_parse(file, @expense_sheet)
              
              if result[:success]
                # 분석 결과 저장
                pdf_result = @expense_sheet.pdf_analysis_results.create!(
                  attachment_id: attachment.id.to_s,
                  extracted_text: result[:extraction][:full_text],
                  analysis_data: {
                    pages: result[:extraction][:pages].count,
                    extraction_errors: result[:extraction][:errors],
                    transactions: result[:parsing][:transactions],
                    transaction_count: result[:parsing][:total_count],
                    match_rate: result[:matching][:match_rate]
                  },
                  card_type: result[:card_type].to_s,
                  detected_amounts: analysis_service.find_amounts(result[:extraction][:full_text]),
                  detected_dates: analysis_service.find_dates(result[:extraction][:full_text]),
                  total_amount: result[:parsing][:total_amount]
                )
                
                # 매칭 결과 저장
                result[:matching][:matches].each do |match|
                  pdf_result.transaction_matches.create!(
                    expense_item: match[:expense_item],
                    transaction_data: match[:transaction],
                    confidence: match[:confidence],
                    match_type: match[:match_type]
                  )
                end
                
                successful_analyses += 1
              else
                error_msg = "#{attachment.filename.to_s}: #{result[:errors]&.join(', ')}"
                analysis_errors << error_msg
                Rails.logger.error "PDF 분석 실패: #{error_msg}"
              end
            end
          rescue => e
            error_msg = "#{attachment.filename.to_s}: #{e.message}"
            analysis_errors << error_msg
            Rails.logger.error "PDF 처리 중 예외 발생: #{error_msg}"
          end
        end
      end
      
      # Turbo Frame 업데이트를 위해 다시 로드
      @pdf_analysis_results = @expense_sheet.pdf_analysis_results.includes(:transaction_matches)
      
      # 결과 메시지 생성
      if successful_analyses > 0 && analysis_errors.empty?
        notice_msg = "PDF 파일이 성공적으로 업로드되고 분석되었습니다."
      elsif successful_analyses > 0 && analysis_errors.any?
        notice_msg = "#{successful_analyses}개 파일이 분석되었습니다. 일부 오류: #{analysis_errors.join('; ')}"
      else
        notice_msg = "PDF 분석 실패: #{analysis_errors.join('; ')}"
      end
      
      respond_to do |format|
        format.html { redirect_to expense_sheets_path, notice: notice_msg }
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace("pdf_analysis_results", 
              partial: "pdf_analysis_results", 
              locals: { pdf_analysis_results: @pdf_analysis_results }),
            turbo_stream.prepend("flash_messages", 
              partial: "shared/flash", 
              locals: { type: analysis_errors.any? ? :alert : :notice, message: notice_msg })
          ]
        }
      end
    else
      redirect_to expense_sheets_path, alert: '업로드할 파일을 선택해주세요.'
    end
  end

  def delete_pdf_attachment
    unless @expense_sheet.editable?
      redirect_to expense_sheets_path, alert: 'PDF를 삭제할 수 없는 상태입니다.'
      return
    end

    attachment = @expense_sheet.pdf_attachments.find(params[:attachment_id])
    
    # 관련 PDF 분석 결과도 삭제
    @expense_sheet.pdf_analysis_results.where(attachment_id: attachment.id).destroy_all
    
    attachment.purge
    redirect_to expense_sheets_path, notice: 'PDF 파일이 삭제되었습니다.'
  rescue ActiveRecord::RecordNotFound
    redirect_to expense_sheets_path, alert: '파일을 찾을 수 없습니다.'
  end

  # 제출 취소
  def cancel_submission
    @expense_sheet = current_user.expense_sheets.find(params[:id])
    
    if @expense_sheet.cancel_submission!(current_user)
      redirect_to expense_sheets_path(year: @expense_sheet.year, month: @expense_sheet.month), 
                  notice: '경비 시트 제출이 취소되었습니다. 다시 수정할 수 있습니다.',
                  status: :see_other
    else
      redirect_to expense_sheets_path(year: @expense_sheet.year, month: @expense_sheet.month), 
                  alert: @expense_sheet.errors.full_messages.join(', '),
                  status: :see_other
    end
  end
  
  # 제출된 경비 시트 내역 확인
  def submission_details
    @expense_sheet = current_user.expense_sheets.find(params[:id])
    
    # 제출된 상태가 아니면 일반 경비 시트 페이지로 리다이렉트
    unless @expense_sheet.status == 'submitted'
      redirect_to expense_sheets_path(year: @expense_sheet.year, month: @expense_sheet.month)
      return
    end
    
    # 경비 항목 로드
    @expense_items = @expense_sheet.expense_items
                                   .not_drafts
                                   .includes(:expense_code, :cost_center, expense_attachments: { file_attachment: :blob })
                                   .ordered
    
    # 시트 레벨 첨부파일 로드
    @sheet_attachments = @expense_sheet.expense_sheet_attachments.includes(:attachment_requirement)
    @required_attachments = AttachmentRequirement.where(attachment_type: 'expense_sheet', active: true).order(:position)
    @uploaded_requirement_ids = @sheet_attachments.pluck(:attachment_requirement_id).compact
    
    # AI 검증 관련 데이터 로드
    @validation_histories = @expense_sheet.validation_histories
    last_validation_history = @validation_histories.last
    @validation_context = if last_validation_history&.full_validation_context.present?
                           last_validation_history.full_validation_context
                         else
                           Rails.cache.read("validation_context_#{@expense_sheet.id}_#{current_user.id}") || {}
                         end
    
    # 결재 관련 데이터 로드
    @approval_request = @expense_sheet.approval_request
    @approval_histories = @approval_request&.approval_histories&.includes(:approver)
    
    # submission_details 뷰를 렌더링
    render :submission_details
  end
  
  # 경비 시트를 엑셀로 내보내기
  def export
    respond_to do |format|
      format.xlsx {
        # 파일명 형식: 이름_월_경비.xlsx
        filename = "#{current_user.name}_#{@expense_sheet.month}월_경비.xlsx"
        response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
      }
    end
  end
  
  # 경비 시트 전체 검증
  def validate_sheet
    SheetValidationJob.perform_later(@expense_sheet.id)
    
    respond_to do |format|
      format.html { 
        redirect_to @expense_sheet, notice: '검증이 시작되었습니다. 잠시 후 결과를 확인해주세요.' 
      }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          "expense_sheet_validation_summary",
          partial: "expense_sheets/validation_summary",
          locals: { expense_sheet: @expense_sheet }
        )
      }
      format.json { render json: { message: '검증이 시작되었습니다' } }
    end
  end
  
  # 모든 경비 항목 개별 검증
  def validate_all_items
    @expense_sheet.expense_items.each do |item|
      next unless item.expense_attachments.any?
      ValidationJob.perform_later(item.id)
    end
    
    respond_to do |format|
      format.html { 
        redirect_to @expense_sheet, notice: '모든 항목의 검증이 시작되었습니다.' 
      }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          "expense_sheet_validation_summary",
          partial: "expense_sheets/validation_summary",
          locals: { expense_sheet: @expense_sheet }
        )
      }
      format.json { 
        render json: { 
          message: '검증이 시작되었습니다',
          items_count: @expense_sheet.expense_items.count
        } 
      }
    end
  end
  
  # 단일 검증 단계 실행
  # 검증 결과 가져오기 (JSON 전용)
  def validation_result
    @expense_sheet = ExpenseSheet.find(params[:id])
    
    # 캐시에서 컨텍스트 가져오기
    context_key = "validation_context_#{@expense_sheet.id}_#{current_user.id}"
    context = Rails.cache.read(context_key) || {}
    
    # 각 단계별 결과 수집
    step_results = []
    total_token_usage = { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 }
    
    (1..3).each do |step|
      step_data = context["step_#{step}"]
      if step_data
        step_results << {
          step: step,
          name: step_data[:name],
          status: step_data[:status],
          validation_details: step_data[:validation_details],
          issues_found: step_data[:issues_found],
          token_usage: step_data[:token_usage],
          debug_info: step_data[:debug_info],
          suggested_order: step_data[:suggested_order]
        }
        
        # 토큰 사용량 누적 (문자열 키와 심볼 키 모두 처리)
        if step_data[:token_usage]
          token_data = step_data[:token_usage]
          total_token_usage[:prompt_tokens] += (token_data[:prompt_tokens] || token_data['prompt_tokens'] || 0).to_i
          total_token_usage[:completion_tokens] += (token_data[:completion_tokens] || token_data['completion_tokens'] || 0).to_i
          total_token_usage[:total_tokens] += (token_data[:total_tokens] || token_data['total_tokens'] || 0).to_i
        end
      end
    end
    
    render json: {
      expense_sheet_id: @expense_sheet.id,
      step_results: step_results,
      total_token_usage: total_token_usage,
      validation_summary: @expense_sheet.validation_result
    }
  end
  
  def validate_step
    # 권한 체크 (본인 또는 어드민)
    unless @expense_sheet.user_id == current_user.id || current_user.admin?
      render json: { error: '검증 권한이 없습니다.' }, status: :forbidden
      return
    end
    
    # 단계 번호 확인
    step_number = params[:step].to_i
    unless (1..4).include?(step_number)
      render json: { error: '유효하지 않은 단계 번호입니다.' }, status: :unprocessable_entity
      return
    end
    
    # 첨부파일 분석 결과 가져오기 (옵셔널 - 없어도 검증 가능)
    sheet_attachments = @expense_sheet.expense_sheet_attachments.where(status: 'completed')
    
    # 경비 항목 리스트 가져오기 (임시 저장 제외)
    expense_items = @expense_sheet.expense_items.not_drafts.includes(:expense_code)
    
    # 검증 서비스 호출 (current_user 전달)
    validation_service = ExpenseValidationService.new(@expense_sheet, current_user)
    
    # Rails 캐시에서 이전 컨텍스트 가져오기 (세션 대신 캐시 사용)
    cache_key = "validation_context_#{@expense_sheet.id}_#{current_user.id}"
    cached_data = Rails.cache.read(cache_key) || {}
    # HashWithIndifferentAccess로 변환하여 Symbol/String 키 모두 접근 가능하게
    previous_context = HashWithIndifferentAccess.new(cached_data)
    
    # 단일 단계만 실행
    result = validation_service.validate_single_step_with_context(
      sheet_attachments, 
      expense_items, 
      step_number,
      previous_context
    )
    
    # 검증 컨텍스트를 캐시에 저장 (다음 단계를 위해, 10분간 유효)
    # HashWithIndifferentAccess를 사용하여 Symbol/String 키 모두 접근 가능하게
    previous_context["step_#{step_number}"] = HashWithIndifferentAccess.new({
      name: result[:name],
      status: result[:status],
      validation_details: result[:validation_details],
      issues_found: result[:issues_found],
      token_usage: result[:token_usage],
      cost_krw: result[:cost_krw],
      debug_info: result[:debug_info],
      suggested_order: result[:suggested_order],
      receipt_check: result[:receipt_check]  # 4단계 영수증 검증 결과 추가
    })
    Rails.cache.write(cache_key, previous_context, expires_in: 10.minutes)
    
    # 마지막 단계인 경우 전체 결과 저장
    if step_number == 4
      final_result = validation_service.compile_all_steps_result(previous_context)
      # 4단계 완료 시 메타 정보 추가
      result[:step] = 4
      result[:name] = '전체 검증 완료'
      result[:is_final] = true
      # 캐시는 validation_result 호출 후 삭제하도록 남겨둠 (10분 후 자동 만료)
      
      # 디버깅 로그
      Rails.logger.info "=== 4단계 검증 완료 ==="
      Rails.logger.info "최종 결과 validation_details 개수: #{final_result[:validation_details]&.size}"
      Rails.logger.info "경비 항목 개수: #{expense_items.size}"
      
      # 최종 결과로 모든 경비 항목 상태 업데이트
      approved_items_reset = []  # 초기화된 승인 항목 추적
      
      if final_result[:validation_details].present?
        Rails.logger.info "validation_details 내용:"
        final_result[:validation_details].each do |detail|
          Rails.logger.info "  - item_id: #{detail['item_id']}, status: #{detail['status']}, message: #{detail['message']}"
          
          item = expense_items.find { |i| i.id == detail['item_id'].to_i }
          if item
            # 승인된 항목이지만 검증에 문제가 있는 경우 처리
            if item.approval_request&.status_approved? && detail['status'] != '완료'
              Rails.logger.info "  🔄 승인된 항목 ##{item.id}에 문제 발견 - 승인 초기화 진행"
              reset_approval_status(item)
              approved_items_reset << item.id
              next  # 승인 초기화한 경우 일반 상태 업데이트 스킵
            end
            
            # 상태 매핑
            new_status = case detail['status']
                        when '완료'
                          'validated'
                        when '확인 필요'
                          'warning'
                        when '미검증'
                          'pending'
                        else
                          'pending'
                        end
            
            Rails.logger.info "  -> ExpenseItem #{item.id} 상태 업데이트: #{item.validation_status} => #{new_status}"
            
            # DB 업데이트
            item.update_columns(
              validation_status: new_status,
              validation_message: detail['message'],
              validated_at: Time.current
            )
          else
            Rails.logger.warn "  -> ExpenseItem #{detail['item_id']} 찾을 수 없음"
          end
        end
      else
        Rails.logger.warn "validation_details가 비어있음"
      end
      
      # ValidationHistory에 저장 (full_validation_context 추가)
      # 승인 초기화 정보를 recommendations에 포함
      recommendations_with_reset = final_result[:recommendations] || []
      if approved_items_reset.any?
        reset_info = "승인 초기화된 항목: #{approved_items_reset.map { |id| "##{id}" }.join(', ')} (AI 검증 중 문제 발견)"
        recommendations_with_reset = recommendations_with_reset.is_a?(Array) ? recommendations_with_reset : []
        recommendations_with_reset << reset_info
        Rails.logger.info "승인 초기화 정보 추가: #{reset_info}"
      end
      
      validation_history = @expense_sheet.validation_histories.create!(
        validated_by: current_user,
        validation_summary: final_result[:validation_summary],
        all_valid: final_result[:all_valid],
        validation_details: final_result[:validation_details],
        issues_found: final_result[:issues_found],
        recommendations: recommendations_with_reset,  # 승인 초기화 정보가 포함된 recommendations
        attachment_data: {},
        full_validation_context: previous_context,  # 전체 검증 컨텍스트 저장
        expense_items_data: @expense_sheet.expense_items.map do |item|
          {
            id: item.id,
            expense_date: item.expense_date,
            expense_code: item.expense_code.name,
            amount: item.amount,
            description: item.description
          }
        end
      )
      
      # 검증 후 경비 항목 다시 로드 (업데이트된 상태 반영, 임시 저장 제외)
      @expense_items = @expense_sheet.expense_items.not_drafts.includes(:expense_code).ordered
      
      # Turbo Stream을 위한 인스턴스 변수 설정
      @step_number = step_number
    end
    
    respond_to do |format|
      format.json { 
        # debug_info와 suggested_order가 포함된 전체 result를 전달
        json_response = result.merge(
          step: step_number,
          is_final: step_number == 4,  # 4단계가 마지막
          debug_info: result[:debug_info] || {}  # debug_info 명시적 포함
        )
        
        # 4단계인 경우 승인 초기화 정보 추가
        if step_number == 4 && defined?(approved_items_reset) && approved_items_reset.any?
          json_response[:approved_items_reset] = approved_items_reset
          json_response[:reset_message] = "승인된 항목 #{approved_items_reset.count}개가 AI 검증 문제로 초기화되었습니다"
        end
        
        # 3단계인 경우 suggested_order 추가
        if step_number == 3 && result[:suggested_order]
          json_response[:suggested_order] = result[:suggested_order]
          Rails.logger.info "JSON 응답에 suggested_order 포함: #{result[:suggested_order].present?}"
        end
        
        # 디버깅을 위한 로깅
        if step_number == 3
          Rails.logger.info "[3단계 JSON 응답]"
          Rails.logger.info "- debug_info 있음: #{json_response[:debug_info].present?}"
          Rails.logger.info "- token_usage 있음: #{json_response[:token_usage].present?}"
          Rails.logger.info "- debug_info.token_usage 있음: #{json_response[:debug_info][:token_usage].present? rescue false}"
          Rails.logger.info "- suggested_order 있음: #{json_response[:suggested_order].present?}"
        end
        
        render json: json_response
      }
      format.turbo_stream {
        # 4단계 완료 시에만 Turbo Stream으로 validation_details_table 업데이트
        if step_number == 4
          render 'validate_step'
        else
          head :ok
        end
      }
    end
  rescue => e
    Rails.logger.error "AI 검증 단계 #{step_number} 중 오류: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { 
      error: "AI 검증 단계 #{step_number} 중 오류가 발생했습니다.",
      details: e.message 
    }, status: :internal_server_error
  end
  
  def validate_with_ai
    # 권한 체크 (본인 또는 어드민)
    unless @expense_sheet.user_id == current_user.id || current_user.admin?
      render json: { error: '검증 권한이 없습니다.' }, status: :forbidden
      return
    end
    
    # 첨부파일 분석 결과 가져오기
    sheet_attachments = @expense_sheet.expense_sheet_attachments.where(status: 'completed')
    
    if sheet_attachments.empty?
      render json: { 
        error: '분석이 완료된 첨부파일이 없습니다.' 
      }, status: :unprocessable_entity
      return
    end
    
    # 경비 항목 리스트 가져오기 (임시 저장 제외)
    expense_items = @expense_sheet.expense_items.not_drafts.includes(:expense_code)
    
    # 검증 서비스 호출 (current_user 전달)
    validation_service = ExpenseValidationService.new(@expense_sheet, current_user)
    
    # 단계별 검증 사용 여부 확인 (파라미터 또는 기본값)
    use_stepwise = params[:stepwise] == 'true' || true  # 기본적으로 단계별 검증 사용
    
    if use_stepwise
      # Turbo Stream을 위한 채널 구독 설정
      @validation_channel = "expense_sheet_#{@expense_sheet.id}_validation"
      
      # 단계별 검증 실행
      result = validation_service.validate_with_ai_stepwise(sheet_attachments, expense_items) do |step, name, status|
        # 진행 상황 로깅
        Rails.logger.info "검증 단계 #{step}: #{name} - #{status}"
      end
    else
      # 기존 방식 (모든 규칙 한번에)
      result = validation_service.validate_with_ai(sheet_attachments, expense_items)
    end
    
    # 검증 후 경비 항목 다시 로드 (업데이트된 상태 반영, 임시 저장 제외)
    @expense_items = @expense_sheet.expense_items.not_drafts.includes(:expense_code).ordered
    
    respond_to do |format|
      format.json { render json: result }
      format.turbo_stream {
        # Turbo Stream으로 경비 항목 테이블과 메트릭 카드 업데이트
        render turbo_stream: [
          turbo_stream.replace("expense_items_table",
            partial: "expense_sheets/expense_items_table",
            locals: { expense_sheet: @expense_sheet, expense_items: @expense_items }
          ),
          turbo_stream.replace("metric_cards",
            partial: "expense_sheets/metric_cards",
            locals: { expense_sheet: @expense_sheet, expense_items: @expense_items }
          )
        ]
      }
    end
  rescue => e
    Rails.logger.error "AI 검증 중 오류: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { 
      error: 'AI 검증 중 오류가 발생했습니다.',
      details: e.message 
    }, status: :internal_server_error
  end
  
  # 검증 이력 조회 액션
  def validation_history
    # 권한 체크 (본인 또는 어드민)
    unless @expense_sheet.user_id == current_user.id || current_user.admin?
      render json: { error: '조회 권한이 없습니다.' }, status: :forbidden
      return
    end
    
    histories = @expense_sheet.validation_histories.recent.limit(10)
    
    render json: histories.map { |h| 
      {
        id: h.id,
        created_at: h.created_at,
        validated_by: h.validated_by.name,
        validation_summary: h.validation_summary,
        all_valid: h.all_valid,
        warning_count: h.warning_count,
        validated_count: h.validated_count,
        pending_count: h.pending_count,
        issues_found: h.issues_found,
        recommendations: h.recommendations,
        validation_details: h.validation_details
      }
    }
  end
  
  # 특정 월의 시트 상태 확인 (AJAX 요청용)
  def check_month_status
    year = params[:year].to_i
    month = params[:month].to_i
    
    # 해당 월의 시트 확인
    sheet = current_user.expense_sheets.find_by(year: year, month: month)
    
    if sheet
      render json: {
        sheet_exists: true,
        editable: sheet.editable?,
        status: sheet.status,
        id: sheet.id
      }
    else
      render json: {
        sheet_exists: false,
        editable: true,
        status: nil,
        id: nil
      }
    end
  end

  private
  
  # AI 검증에서 문제가 발견된 승인된 항목을 초기화
  def reset_approval_status(expense_item)
    return unless expense_item.approval_request&.status_approved?
    
    ActiveRecord::Base.transaction do
      # 승인 요청 상태를 pending으로 변경
      expense_item.approval_request.update!(
        status: 'pending',
        current_step: 1  # 첫 단계로 초기화
      )
      
      # 승인 이력에 초기화 기록 추가
      expense_item.approval_request.approval_histories.create!(
        approver: current_user,
        step_order: 0,  # 특별 단계 번호 사용
        action: 'reset',  # status가 아니라 action이어야 함
        role: 'approve',  # role 필드 추가 (필수 필드)
        comment: 'AI 검증에서 추가 확인이 필요하여 승인 상태 초기화',
        approved_at: Time.current
      )
      
      # 경비 항목의 validation_status 업데이트
      expense_item.update!(
        validation_status: 'warning',
        validation_message: 'AI 검증 결과 추가 확인 필요 - 승인 상태가 초기화되었습니다'
      )
      
      Rails.logger.info "🔄 경비 항목 ##{expense_item.id} 승인 상태 초기화 완료"
    end
  rescue => e
    Rails.logger.error "승인 상태 초기화 중 오류: #{e.message}"
    raise
  end

  def prepare_approval_lines_data
    current_user.approval_lines.active.includes(
      approval_line_steps: { approver: :approver_groups }
    ).each_with_object({}) do |line, hash|
      hash[line.id] = {
        id: line.id,
        name: line.name,
        approvers: line.approval_line_steps.ordered.map do |step|
          {
            id: step.approver_id,
            name: step.approver.name,
            step_order: step.step_order,
            role: step.role,
            approval_type: step.approval_type,
            groups: step.approver.approver_groups.map { |g| 
              { id: g.id, name: g.name, priority: g.priority }
            }
          }
        end
      }
    end
  end

  def prepare_expense_sheet_rules_data
    ExpenseSheetApprovalRule.active.includes(:approver_group, :submitter_group).map do |rule|
      {
        id: rule.id,
        rule_type: rule.rule_type,
        condition: rule.condition,
        submitter_group_id: rule.submitter_group_id,
        approver_group: {
          id: rule.approver_group.id,
          name: rule.approver_group.name,
          priority: rule.approver_group.priority,
          members: rule.approver_group.members.pluck(:id)
        }
      }
    end
  end

  def prepare_current_user_groups_data
    current_user.approver_groups.map do |group|
      { id: group.id, name: group.name, priority: group.priority }
    end
  end

  def set_expense_sheet
    # 모든 사용자는 자신의 경비 시트만 볼 수 있음 (관리자 포함)
    @expense_sheet = current_user.expense_sheets.find(params[:id])
  end

  def expense_sheet_params
    params.require(:expense_sheet).permit(:year, :month, :remarks)
  end

  def attach_pdf_files(pdf_files)
    max_file_size = 10.megabytes
    invalid_files = []
    
    pdf_files.each do |file|
      # 파일 객체가 아닌 경우 체크
      if file.is_a?(String)
        invalid_files << "잘못된 파일 형식입니다. 파일을 다시 선택해주세요."
        next
      end
      
      # 파일 객체가 맞는지 추가 검증
      unless file.respond_to?(:content_type) && file.respond_to?(:size)
        invalid_files << "파일 업로드 오류가 발생했습니다."
        next
      end
      
      if file.size > max_file_size
        invalid_files << "#{file.original_filename}: 파일 크기가 10MB를 초과합니다"
      elsif file.content_type != 'application/pdf'
        invalid_files << "#{file.original_filename}: PDF 파일만 업로드 가능합니다"
      end
    end
    
    return invalid_files if invalid_files.any?
    
    @expense_sheet.pdf_attachments.attach(pdf_files)
    []
  end

  def analyze_pdf_attachments
    # PDF 분석 서비스가 있다면 사용, 없으면 스킵
    return unless defined?(PdfAnalysisService)
    
    analysis_service = PdfAnalysisService.new
    analyzed_attachment_ids = @expense_sheet.pdf_analysis_results.pluck(:attachment_id)
    
    @expense_sheet.pdf_attachments.each do |attachment|
      next if analyzed_attachment_ids.include?(attachment.id.to_s)
      
      if attachment.blob.content_type == 'application/pdf'
        begin
          attachment.blob.open do |file|
            result = analysis_service.analyze_and_parse(file, @expense_sheet)
            
            if result[:success]
              # 분석 결과 저장
              pdf_result = @expense_sheet.pdf_analysis_results.create!(
                attachment_id: attachment.id.to_s,
                extracted_text: result[:extraction][:full_text],
                analysis_data: {
                  pages: result[:extraction][:pages].count,
                  extraction_errors: result[:extraction][:errors],
                  transactions: result[:parsing][:transactions],
                  transaction_count: result[:parsing][:total_count],
                  match_rate: result[:matching][:match_rate]
                },
                card_type: result[:card_type].to_s,
                detected_amounts: analysis_service.find_amounts(result[:extraction][:full_text]),
                detected_dates: analysis_service.find_dates(result[:extraction][:full_text]),
                total_amount: result[:parsing][:total_amount]
              )
              
              # 매칭 결과 저장
              result[:matching][:matches].each do |match|
                pdf_result.transaction_matches.create!(
                  expense_item: match[:expense_item],
                  transaction_data: match[:transaction],
                  confidence: match[:confidence],
                  match_type: match[:match_type]
                )
              end
            end
          end
        rescue => e
          Rails.logger.error "PDF 분석 중 오류: #{e.message}"
        end
      end
    end
  end
end