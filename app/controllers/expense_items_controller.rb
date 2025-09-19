# TO-DO: 경비 항목 폼을 Turbo로 전환 필요
# - create, update 액션에 turbo_stream 응답 형식 추가
# - 에러 처리를 Turbo Stream으로 변경
# - app/views/expense_items/_form.html.erb의 turbo: false 제거
# - autosave_controller.js의 Turbo 이벤트 수동 처리 제거
# - Rails 7+ Turbo 표준 방식으로 전체 폼 처리 통일

class ExpenseItemsController < ApplicationController
  include TurboCacheControl
  include ActionView::Helpers::NumberHelper
  
  before_action :require_login
  before_action :set_expense_sheet
  before_action :set_expense_item, only: [:edit, :update, :destroy, :cancel_approval]
  before_action :check_editable, except: [:validate_approval_line, :validate_field, :validate_all, :save_draft, :restore_draft, :cancel_approval]

  def new
    # 임시 저장된 항목이 있는지 확인
    if params[:restore_draft] == 'true' && params[:draft_id].present?
      # 특정 draft ID로 복원
      @draft_item = @expense_sheet.expense_items.drafts.find_by(id: params[:draft_id])
      if @draft_item
        # draft 객체를 직접 사용하지 않고 새로운 객체를 만들어서 데이터 복사
        @expense_item = @expense_sheet.expense_items.build
        @expense_item.restore_from_draft_data(@draft_item.draft_data)
        # draft_id를 별도 인스턴스 변수로 전달
        @draft_id = @draft_item.id
        
        Rails.logger.debug "=== Draft restore in controller ==="
        Rails.logger.debug "Draft ID: #{@draft_item.id}"
        Rails.logger.debug "Draft data: #{@draft_item.draft_data.inspect}"
        Rails.logger.debug "Expense item custom_fields after restore: #{@expense_item.custom_fields.inspect}"
        
        # 플래시 메시지 대신 인스턴스 변수로 전달
        @draft_restore_message = "임시 저장된 내용을 불러왔습니다. (#{@draft_item.draft_status_message})"
      else
        @expense_item = @expense_sheet.expense_items.build
      end
    elsif params[:restore_draft] == 'true'
      # 가장 최근 draft로 복원
      @draft_item = @expense_sheet.expense_items.drafts.order(last_saved_at: :desc).first
      if @draft_item
        @expense_item = @expense_sheet.expense_items.build
        @expense_item.restore_from_draft_data(@draft_item.draft_data)
        @draft_id = @draft_item.id
        # 플래시 메시지 대신 인스턴스 변수로 전달
        @draft_restore_message = "임시 저장된 내용을 불러왔습니다. (#{@draft_item.draft_status_message})"
      else
        @expense_item = @expense_sheet.expense_items.build
      end
    else
      @expense_item = @expense_sheet.expense_items.build
      
      # 마지막 경비 항목의 날짜를 기본값으로 설정
      last_expense_item = current_user.expense_sheets
                                      .joins(:expense_items)
                                      .where(expense_items: { is_draft: false })
                                      .order('expense_items.expense_date DESC')
                                      .limit(1)
                                      .pluck('expense_items.expense_date')
                                      .first
      
      if last_expense_item
        @expense_item.expense_date = last_expense_item
      end
      
      # 가장 최근 임시 저장만 찾기 (여러 개가 있어도 최신 것만)
      @draft_item = @expense_sheet.expense_items.drafts.order(last_saved_at: :desc).first
    end
    
    @expense_codes = ExpenseCode.active.current.joins("LEFT JOIN expense_codes v1 ON expense_codes.code = v1.code AND v1.version = 1").order(Arel.sql("COALESCE(v1.id, expense_codes.id)"))
    @cost_centers = current_user.available_cost_centers
    Rails.logger.info "=== Cost Centers Debug ==="
    Rails.logger.info "User: #{current_user.email}"
    Rails.logger.info "Cost centers count: #{@cost_centers.count}"
    Rails.logger.info "Cost centers: #{@cost_centers.pluck(:id, :name).inspect}"
    @approval_lines = current_user.approval_lines.active.ordered_by_position.includes(approval_line_steps: :approver)
    
    # 모든 경비 코드의 상세 정보를 미리 로드
    prepare_expense_codes_data
    # 결재선별 승인자 그룹 정보 준비
    prepare_approval_lines_data
  end

  # 결재선 선택 시 검증
  def validate_approval_line
    Rails.logger.info "=== validate_approval_line 파라미터 ==="
    Rails.logger.info "expense_code_id: #{params[:expense_code_id]}"
    Rails.logger.info "approval_line_id: #{params[:approval_line_id]}"
    Rails.logger.info "is_budget: #{params[:is_budget]}"
    Rails.logger.info "amount: #{params[:amount]}"
    Rails.logger.info "budget_amount: #{params[:budget_amount]}"
    
    @expense_code = ExpenseCode.find_by(id: params[:expense_code_id])
    @approval_line = ApprovalLine.find_by(id: params[:approval_line_id])
    
    # 예산 모드인지 확인하고 적절한 금액 사용
    is_budget = params[:is_budget] == 'true'
    @amount = if is_budget
                params[:budget_amount].to_i
              else
                params[:amount].to_i
              end
    
    Rails.logger.info "사용할 금액 (is_budget: #{is_budget}): #{@amount}"
    
    if @expense_code
      Rails.logger.info "찾은 경비 코드: #{@expense_code.name_with_code} (ID: #{@expense_code.id}, Version: #{@expense_code.version}, Current: #{@expense_code.is_current})"
    end
    
    # expense_sheet에 approval_line 설정
    if @approval_line
      @expense_sheet.approval_line = @approval_line
    end
    
    @expense_item = @expense_sheet.expense_items.build(
      expense_code: @expense_code,
      amount: @amount,
      is_budget: is_budget,
      budget_amount: is_budget ? @amount : nil
    )
    
    if @expense_code.present?
      Rails.logger.info "=== 승인 규칙 평가 시작 ==="
      Rails.logger.info "경비 코드: #{@expense_code.name_with_code}"
      Rails.logger.info "금액: #{@amount}"
      
      all_rules = @expense_code.expense_code_approval_rules.active.ordered.includes(:approver_group)
      Rails.logger.info "전체 활성 규칙 수: #{all_rules.count}"
      
      all_rules.each do |rule|
        Rails.logger.info "  규칙 #{rule.id}: 조건='#{rule.condition}', 그룹='#{rule.approver_group.name}'"
      end
      
      triggered_rules = all_rules.select do |rule|
        result = rule.evaluate(@expense_item)
        Rails.logger.info "  규칙 #{rule.id} 평가: 조건='#{rule.condition}' => #{result}"
        Rails.logger.info "    - expense_item.amount: #{@expense_item.amount}"
        Rails.logger.info "    - expense_item.expense_code: #{@expense_item.expense_code&.name_with_code}"
        result
      end
      
      Rails.logger.info "트리거된 규칙 수: #{triggered_rules.count}"
      
      # 본인이 이미 권한을 가진 규칙은 제외
      triggered_rules_filtered = triggered_rules.reject do |rule|
        satisfied = rule.already_satisfied_by_user?(current_user)
        Rails.logger.info "  규칙 #{rule.id} (#{rule.approver_group.name}): 사용자가 이미 권한 보유? #{satisfied}"
        satisfied
      end
      
      Rails.logger.info "필터링 후 규칙 수: #{triggered_rules_filtered.count}"
      
      if triggered_rules_filtered.any?
        required_groups = triggered_rules_filtered.map(&:approver_group).uniq
        
        if @approval_line.blank?
          @validation_type = :error
          @validation_message = "승인 필요: #{required_groups.map(&:name).join(', ')}"
        else
          # 결재선이 선택된 경우 검증
          validator = ExpenseValidation::ApprovalLineValidator.new(@expense_item)
          validation_result = validator.validate
          
          Rails.logger.info "=== 결재선 검증 디버깅 ==="
          Rails.logger.info "Expense Code: #{@expense_code.name_with_code}"
          Rails.logger.info "Approval Line: #{@approval_line.name}"
          Rails.logger.info "Triggered Rules: #{triggered_rules_filtered.map { |r| "#{r.approver_group.name} (priority: #{r.approver_group.priority})" }.join(', ')}"
          Rails.logger.info "Validation Result: #{validation_result}"
          Rails.logger.info "Errors: #{validator.error_messages.join(', ')}"
          Rails.logger.info "Warnings: #{validator.warnings.inspect}"
          
          if validation_result
            # 경고 확인
            if validator.warnings.any?
              @validation_type = :warning
              warning = validator.warnings.first
              @validation_message = warning[:message]
            else
              @validation_type = :success
              @validation_message = "승인 조건 충족"
            end
          else
            @validation_type = :error
            # 모든 필요한 승인자 그룹 이름 추출
            missing_groups = validator.error_messages.map { |msg| msg.gsub("승인 필요: ", "") }.uniq
            @validation_message = "승인 필요: #{missing_groups.join(', ')}"
          end
        end
      elsif @approval_line.present?
        # 승인 규칙이 없는데 결재선이 있는 경우도 검증
        validator = ExpenseValidation::ApprovalLineValidator.new(@expense_item)
        validator.validate
        
        if validator.warnings.any?
          @validation_type = :warning
          warning = validator.warnings.first
          @validation_message = warning[:message]
        end
      end
    end
    
    respond_to do |format|
      format.turbo_stream
    end
  end

  def create
    Rails.logger.info "=== ExpenseItemsController#create START ==="
    Rails.logger.info "Params: #{params.inspect}"
    
    @expense_item = @expense_sheet.expense_items.build(expense_item_params)
    
    # 임시 저장 상태 해제
    @expense_item.is_draft = false
    @expense_item.draft_data = {}
    
    # 먼저 대상 시트 확인
    target_sheet = nil
    if @expense_item.expense_date.present?
      target_sheet = ExpenseSheet.find_by(
        user: current_user,
        year: @expense_item.expense_date.year,
        month: @expense_item.expense_date.month
      )
      
      # 기존 시트가 있고 편집 불가능한 상태라면
      if target_sheet && !target_sheet.editable?
        respond_to do |format|
          format.html { 
            redirect_to new_expense_sheet_expense_item_path(@expense_sheet), 
                       alert: "#{target_sheet.year}년 #{target_sheet.month}월 시트는 이미 제출되었습니다. 다른 날짜를 선택해주세요." 
          }
          format.turbo_stream { 
            redirect_to new_expense_sheet_expense_item_path(@expense_sheet), 
                       alert: "#{target_sheet.year}년 #{target_sheet.month}월 시트는 이미 제출되었습니다. 다른 날짜를 선택해주세요." 
          }
        end
        return
      end
    end
    
    success = ActiveRecord::Base.transaction do
      # 첨부 파일 ID로 연결 (즉시 업로드된 파일들)
      if params[:attachment_ids].present?
        attachment_ids = params[:attachment_ids]
        attachment_ids.each do |attachment_id|
          attachment = ExpenseAttachment.find_by(id: attachment_id)
          if attachment && attachment.expense_item_id.nil?
            @expense_item.expense_attachments << attachment
          end
        end
      end
      
      # 이제 expense_item 저장 (첨부파일이 연결된 상태에서 검증 실행)
      if @expense_item.save
        Rails.logger.info "=== ExpenseItem saved successfully, ID: #{@expense_item.id} ==="
        # ApprovalRequest는 모델의 after_create 콜백에서 자동 생성됨
        true
      else
        Rails.logger.error "=== ExpenseItem save failed: #{@expense_item.errors.full_messages.join(', ')} ==="
        false
      end
    end
    
    if success
      # 트랜잭션 커밋 후 즉시 변경사항 반영
      ActiveRecord::Base.connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
      
      Rails.logger.info "=== SUCCESS: Redirecting to expense_sheets_path ==="
      
      # 시트가 없거나 편집 가능한 경우에만 찾기 또는 생성
      target_sheet ||= ExpenseSheet.find_or_create_by(
        user: current_user,
        year: @expense_item.expense_date.year,
        month: @expense_item.expense_date.month
      ) do |sheet|
        sheet.organization = current_user.organization
        sheet.status = 'draft'
      end
      
      # 모든 형식에 대해 동일하게 리다이렉트 처리
      redirect_to expense_sheets_path(year: target_sheet.year, month: target_sheet.month), 
                 notice: '경비 항목이 추가되었습니다.', 
                 status: :see_other
      return
    else
      Rails.logger.error "ExpenseItem validation errors: #{@expense_item.errors.full_messages.join(', ')}"
      
      # 검증 실패 시에도 첨부파일 연결 유지
      Rails.logger.info "Preserving #{@expense_item.expense_attachments.length} attachments after validation failure"
      
      @expense_codes = ExpenseCode.active.current.joins("LEFT JOIN expense_codes v1 ON expense_codes.code = v1.code AND v1.version = 1").order(Arel.sql("COALESCE(v1.id, expense_codes.id)"))
      @cost_centers = current_user.available_cost_centers
      @approval_lines = current_user.approval_lines.active.ordered_by_position.includes(approval_line_steps: :approver)
      
      # JavaScript를 위한 경비 코드 데이터 준비
      prepare_expense_codes_data
      # 결재선별 승인자 그룹 정보 준비
      prepare_approval_lines_data
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("expense_form",
            partial: "expense_items/form",
            locals: { 
              expense_sheet: @expense_sheet,
              expense_item: @expense_item
            })
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
    # 읽기 전용 모드 체크
    @readonly_mode = @expense_item.readonly_mode?
    @actual_amount_input_only = @expense_item.actual_amount_input_only?
    
    # 현재 선택된 경비 코드가 구 버전이라도 포함시키기
    if @expense_item.expense_code && !@expense_item.expense_code.is_current
      # 현재 버전 + 선택된 구 버전 포함
      @expense_codes = ExpenseCode.active
                                   .where("expense_codes.is_current = ? OR expense_codes.id = ?", true, @expense_item.expense_code_id)
                                   .joins("LEFT JOIN expense_codes v1 ON expense_codes.code = v1.code AND v1.version = 1")
                                   .order(Arel.sql("COALESCE(v1.id, expense_codes.id)"))
    else
      @expense_codes = ExpenseCode.active.current
                                   .joins("LEFT JOIN expense_codes v1 ON expense_codes.code = v1.code AND v1.version = 1")
                                   .order(Arel.sql("COALESCE(v1.id, expense_codes.id)"))
    end
    
    @cost_centers = current_user.available_cost_centers
    @approval_lines = current_user.approval_lines.active.ordered_by_position.includes(approval_line_steps: :approver)
    
    # 기존 첨부파일 로드 (eager loading) - reload 강제 실행으로 최신 데이터 확보
    if @expense_item.persisted?
      @expense_item.expense_attachments.reload
      Rails.logger.debug "Loaded #{@expense_item.expense_attachments.count} attachments for expense_item ##{@expense_item.id}"
      @expense_item.expense_attachments.each do |att|
        Rails.logger.debug "  - Attachment ##{att.id}: status='#{att.status}' (class: #{att.status.class}), has_text=#{att.extracted_text.present?}, text_length=#{att.extracted_text.to_s.length}"
        Rails.logger.debug "    Condition check: status=='completed' => #{att.status == 'completed'}, text.present? => #{att.extracted_text.present?}"
        Rails.logger.debug "    Combined condition => #{att.status == 'completed' && att.extracted_text.present?}"
      end
    end
    
    # 모든 경비 코드의 상세 정보를 미리 로드
    prepare_expense_codes_data
    # 결재선별 승인자 그룹 정보 준비
    prepare_approval_lines_data
  end

  def update
    # 읽기 전용 모드 체크
    if @expense_item.readonly_mode?
      redirect_to edit_expense_sheet_expense_item_path(@expense_sheet, @expense_item), 
                  alert: '승인 진행 중이거나 완료된 항목은 수정할 수 없습니다.'
      return
    end
    
    # 예산 승인된 항목에 실제 집행 금액 입력 시 처리
    if @expense_item.is_budget? && params[:expense_item][:actual_amount].present?
      actual_amount = params[:expense_item][:actual_amount].to_d
      budget_amount = @expense_item.budget_amount
      
      # 예산 초과 체크
      if actual_amount > budget_amount
        @expense_item.budget_exceeded = true
        @expense_item.excess_reason = params[:expense_item][:excess_reason]
        
        # 예산 초과 시 재승인 필요 - 새로운 ApprovalRequest 생성
        if @expense_item.approval_request&.status == 'approved'
          # 기존 승인 요청을 재승인 대기 상태로 변경
          @expense_item.approval_request.update(status: 'pending', current_step: 1)
          
          # 실제 승인 시점 기록
          @expense_item.actual_approved_at = nil
        end
      else
        @expense_item.budget_exceeded = false
        @expense_item.excess_reason = nil
        
        # 예산 내에서 집행된 경우 승인 완료 처리
        @expense_item.actual_approved_at = Time.current if @expense_item.actual_approved_at.blank?
      end
    end
    
    # 첨부 파일을 먼저 처리 (유효성 검사 전에)
    @removed_attachment_ids = []
    
    if params[:attachment_ids].present?
      # 기존 첨부파일과 새로운 첨부파일 ID 비교
      new_attachment_ids = params[:attachment_ids].map(&:to_i)
      existing_attachment_ids = @expense_item.expense_attachments.pluck(:id)
      
      # 새로 추가된 첨부파일 연결
      (new_attachment_ids - existing_attachment_ids).each do |attachment_id|
        attachment = ExpenseAttachment.find_by(id: attachment_id)
        if attachment && attachment.expense_item_id.nil?
          @expense_item.expense_attachments << attachment
        end
      end
      
      # 제거된 첨부파일 연결 해제는 나중에 처리
      @removed_attachment_ids = existing_attachment_ids - new_attachment_ids
    end
    
    # 임시 저장 상태 해제
    @expense_item.is_draft = false
    @expense_item.draft_data = {}
    
    # 첨부파일을 연결한 후 update 실행
    if @expense_item.update(expense_item_params)
      # 제거된 첨부파일 연결 해제 (성공 시에만)
      if @removed_attachment_ids.present?
        @removed_attachment_ids.each do |attachment_id|
          attachment = ExpenseAttachment.find_by(id: attachment_id, expense_item_id: @expense_item.id)
          attachment&.update(expense_item_id: nil)
        end
      end
      
      # after_update 콜백이 자동으로 취소된 승인 요청을 재생성함
      Rails.logger.info "ExpenseItem ##{@expense_item.id}: update 완료, after_update 콜백이 승인 요청 재생성 처리"
      
      # 수정된 경비 항목의 날짜로 경비 시트 찾기 또는 생성
      target_sheet = ExpenseSheet.find_or_create_by(
        user: current_user,
        year: @expense_item.expense_date.year,
        month: @expense_item.expense_date.month
      ) do |sheet|
        sheet.organization = current_user.organization
        sheet.status = 'draft'
      end
      
      respond_to do |format|
        format.html { 
          redirect_to expense_sheets_path(year: target_sheet.year, month: target_sheet.month), 
                      notice: '경비 항목이 수정되었습니다.', 
                      status: :see_other 
        }
        format.turbo_stream do
          redirect_to expense_sheets_path(year: target_sheet.year, month: target_sheet.month), 
                      notice: '경비 항목이 수정되었습니다.', 
                      status: :see_other
        end
      end
    else
      # 유효성 검사 실패 시 커스텀 필드 값 유지
      Rails.logger.info "Validation failed, preserving custom_fields: #{@expense_item.custom_fields.inspect}"
      
      # 현재 선택된 경비 코드가 구 버전이라도 포함시키기
      if @expense_item.expense_code && !@expense_item.expense_code.is_current
        @expense_codes = ExpenseCode.active
                                     .where("expense_codes.is_current = ? OR expense_codes.id = ?", true, @expense_item.expense_code_id)
                                     .joins("LEFT JOIN expense_codes v1 ON expense_codes.code = v1.code AND v1.version = 1")
                                     .order(Arel.sql("COALESCE(v1.id, expense_codes.id)"))
      else
        @expense_codes = ExpenseCode.active.current
                                     .joins("LEFT JOIN expense_codes v1 ON expense_codes.code = v1.code AND v1.version = 1")
                                     .order(Arel.sql("COALESCE(v1.id, expense_codes.id)"))
      end
      
      @cost_centers = current_user.available_cost_centers
      @approval_lines = current_user.approval_lines.active.ordered_by_position.includes(approval_line_steps: :approver)
      
      # JavaScript를 위한 경비 코드 데이터 준비
      prepare_expense_codes_data
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("expense_form",
            partial: "expense_items/form",
            locals: { 
              expense_sheet: @expense_sheet,
              expense_item: @expense_item
            })
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::StaleObjectError
    @expense_item.reload
    flash.now[:alert] = '다른 사용자가 이 항목을 수정했습니다. 변경사항을 확인하고 다시 시도해주세요.'
    @expense_codes = ExpenseCode.active.current.joins("LEFT JOIN expense_codes v1 ON expense_codes.code = v1.code AND v1.version = 1").order(Arel.sql("COALESCE(v1.id, expense_codes.id)"))
    @cost_centers = current_user.available_cost_centers
    @approval_lines = current_user.approval_lines.active.ordered_by_position.includes(approval_line_steps: :approver)
    
    # JavaScript를 위한 경비 코드 데이터 준비
    prepare_expense_codes_data
    
    render :edit, status: :conflict
  end

  def destroy
    year = @expense_sheet.year
    month = @expense_sheet.month
    
    @expense_item.destroy
    
    respond_to do |format|
      format.turbo_stream do
        # Turbo Stream으로 항목 제거 및 합계 업데이트
        render turbo_stream: [
          turbo_stream.remove(dom_id(@expense_item)),
          turbo_stream.replace("expense_sheet_total", 
            partial: "expense_sheets/total_section", 
            locals: { expense_sheet: @expense_sheet }),
          turbo_stream.prepend("flash-messages", 
            partial: "shared/flash", 
            locals: { message: "경비 항목이 삭제되었습니다.", type: "notice" })
        ]
      end
      format.html { 
        redirect_to expense_sheets_path(year: year, month: month), 
                   notice: '경비 항목이 삭제되었습니다.' 
      }
    end
  end
  
  # 임시 저장
  def save_draft
    # 새 항목이면 생성, 기존 항목이면 업데이트
    if params[:id].present? && params[:id] != 'save_draft'
      # member action - 기존 draft 업데이트
      @expense_item = @expense_sheet.expense_items.find(params[:id])
    elsif params[:draft_id].present?
      # collection action에서 draft_id로 기존 draft 찾기
      @expense_item = @expense_sheet.expense_items.find(params[:draft_id])
    else
      # collection action - 새 draft 생성
      @expense_item = @expense_sheet.expense_items.build
    end
    
    # draft_params에 attachment_ids 추가
    draft_data = draft_params
    draft_data[:attachment_ids] = params[:attachment_ids] if params[:attachment_ids].present?
    
    # 임시 저장 (검증 없이)
    success = @expense_item.save_as_draft(draft_data)
    
    respond_to do |format|
      format.turbo_stream do
        if success
          render turbo_stream: turbo_stream.replace("autosave_status",
            partial: "expense_items/autosave_status",
            locals: { 
              status: "임시 저장됨", 
              timestamp: @expense_item.last_saved_at,
              draft_id: @expense_item.id
            })
        else
          render turbo_stream: turbo_stream.replace("autosave_status",
            partial: "expense_items/autosave_status",
            locals: { 
              status: "저장 실패", 
              error: true
            })
        end
      end
      format.json do
        if success
          render json: { 
            success: true, 
            message: "임시 저장되었습니다.",
            draft_id: @expense_item.id,
            saved_at: @expense_item.last_saved_at.strftime("%Y-%m-%d %H:%M")
          }
        else
          render json: { 
            success: false, 
            message: "임시 저장에 실패했습니다."
          }, status: :unprocessable_entity
        end
      end
    end
  end
  
  # 최근 제출 내역 가져오기
  def recent_submission
    expense_code_id = params[:expense_code_id]
    
    Rails.logger.info "=== recent_submission 호출 ==="
    Rails.logger.info "expense_code_id: #{expense_code_id}"
    Rails.logger.info "current_user: #{current_user.id} (#{current_user.name})"
    
    # 사용자가 사용 가능한 코스트 센터 ID 목록
    available_cost_center_ids = current_user.available_cost_centers.pluck(:id)
    Rails.logger.info "사용 가능한 코스트 센터 IDs: #{available_cost_center_ids}"
    
    # 사용자의 모든 경비 항목 (is_draft가 false인 것만 - 실제 제출된 항목)
    # expense_sheet의 상태는 무관 - 경비 항목이 생성되었으면 참고 가능
    all_items = ExpenseItem.joins(:expense_sheet)
                          .where(expense_sheets: { user_id: current_user.id })
                          .where(expense_code_id: expense_code_id)
                          .where(is_draft: false)  # 임시저장이 아닌 실제 제출된 항목
    
    Rails.logger.info "제출된 항목 수: #{all_items.count}"
    
    # 사용 가능한 코스트 센터를 가진 항목 우선
    recent_item = all_items.where(cost_center_id: available_cost_center_ids)
                          .order('expense_items.id DESC')
                          .first
    
    # 사용 가능한 코스트 센터를 가진 항목이 없으면 모든 항목 중 최신
    if recent_item.nil?
      Rails.logger.info "사용 가능한 코스트 센터를 가진 항목이 없음, 모든 항목에서 검색"
      recent_item = all_items.order('expense_items.id DESC').first
    end
    
    if recent_item
      Rails.logger.info "찾은 항목: #{recent_item.id}"
      Rails.logger.info "custom_fields: #{recent_item.custom_fields.inspect}"
      Rails.logger.info "cost_center_id: #{recent_item.cost_center_id}"
      Rails.logger.info "approval_line_id: #{recent_item.approval_line_id}"
      Rails.logger.info "expense_date: #{recent_item.expense_date}"
      Rails.logger.info "created_at: #{recent_item.created_at}"
      
      # 응답에 디버깅 정보 추가
      render json: {
        success: true,
        data: {
          custom_fields: recent_item.custom_fields || {},
          cost_center_id: recent_item.cost_center_id,
          approval_line_id: recent_item.approval_line_id,
          remarks: recent_item.remarks,
          amount: recent_item.amount
        },
        debug: {
          item_id: recent_item.id,
          expense_date: recent_item.expense_date,
          created_at: recent_item.created_at
        }
      }
    else
      Rails.logger.info "최근 제출 내역 없음"
      render json: { success: false, message: '최근 제출 내역이 없습니다.' }
    end
  end
  
  # 임시 저장 복원
  def restore_draft
    @draft_item = @expense_sheet.expense_items.drafts.find(params[:id])
    
    if @draft_item
      # 플래시 메시지 없이 리다이렉트 (new 액션에서 인라인으로 표시)
      redirect_to new_expense_sheet_expense_item_path(@expense_sheet, restore_draft: true, draft_id: @draft_item.id)
    else
      redirect_to new_expense_sheet_expense_item_path(@expense_sheet), 
                  alert: "임시 저장된 항목을 찾을 수 없습니다."
    end
  end

  # 임시 저장 삭제 (AJAX용)
  def delete_draft
    @draft_item = @expense_sheet.expense_items.drafts.find(params[:id])
    
    if @draft_item
      @draft_item.destroy
      render json: { success: true, message: '임시 저장된 항목이 삭제되었습니다.' }
    else
      render json: { success: false, message: '임시 저장된 항목을 찾을 수 없습니다.' }, status: :not_found
    end
  end
  
  # 승인 요청 취소
  def cancel_approval
    if @expense_item.approval_request&.status_pending?
      if @expense_item.approval_request.cancel!
        redirect_to edit_expense_sheet_expense_item_path(@expense_sheet, @expense_item), 
                    notice: '승인 요청이 취소되었습니다. 이제 수정할 수 있습니다.'
      else
        redirect_to edit_expense_sheet_expense_item_path(@expense_sheet, @expense_item), 
                    alert: '승인 요청 취소 중 오류가 발생했습니다.'
      end
    else
      redirect_to edit_expense_sheet_expense_item_path(@expense_sheet, @expense_item), 
                  alert: '취소할 수 있는 승인 요청이 없습니다.'
    end
  end

  # 통합 검증 엔드포인트 - 모든 검증을 한 곳에서 처리
  def validate_all
    # 경비 항목 준비
    if params[:id].present?
      @expense_item = @expense_sheet.expense_items.find(params[:id])
      @expense_item.assign_attributes(expense_item_params)
    else
      @expense_item = @expense_sheet.expense_items.build(expense_item_params)
    end

    # 경비 코드 로드
    if params[:expense_item][:expense_code_id].present?
      @expense_code = ExpenseCode.find_by(id: params[:expense_item][:expense_code_id])
      @expense_item.expense_code = @expense_code
    end

    # 결재선 로드
    if params[:expense_item][:approval_line_id].present?
      @approval_line = current_user.approval_lines.active.find_by(id: params[:expense_item][:approval_line_id])
    end

    # 모든 검증 수행
    validation_result = {
      valid: true,
      field_errors: {},      # 필드별 에러
      approval_errors: [],    # 결재선 관련 에러
      attachment_errors: [],  # 첨부파일 관련 에러
      general_warnings: [],   # 일반 경고 (한도 등)
      info_messages: []       # 정보성 메시지
    }

    # 1. 필드 검증
    @expense_item.valid?
    if @expense_item.errors.any?
      validation_result[:valid] = false
      @expense_item.errors.each do |error|
        field_name = error.attribute.to_s
        validation_result[:field_errors][field_name] ||= []
        validation_result[:field_errors][field_name] << error.message
      end
    end

    # 1-1. Custom fields 검증 (예: OTME의 참석자, 사유)
    if @expense_code.present? && @expense_code.validation_rules.present?
      required_fields = @expense_code.validation_rules['required_fields']
      if required_fields.present?
        Rails.logger.debug "=== Custom fields validation ==="
        Rails.logger.debug "Required fields: #{required_fields.inspect}"
        Rails.logger.debug "Custom fields params: #{params[:expense_item][:custom_fields].inspect}"
        
        required_fields.each do |field_key, field_config|
          if field_config['required'] != false
            custom_value = params[:expense_item][:custom_fields]&.[](field_key)
            
            # 멀티셀렉트 필드의 경우 빈 문자열이 배열로 전달될 수 있음
            if field_config['type'] == 'participants' || field_config['type'] == 'organization'
              # FormData에서 빈 값은 [''] 배열로 올 수 있음
              if custom_value.is_a?(Array) && custom_value.length == 1 && custom_value[0] == ''
                custom_value = []
              end
            end
            
            Rails.logger.debug "Field #{field_key}: value=#{custom_value.inspect}, type=#{field_config['type']}"
            
            # type이 participants나 organization인 경우 (멀티셀렉트)
            if field_config['type'] == 'participants' || field_config['type'] == 'organization'
              # 값이 없거나 빈 배열이거나 빈 문자열인 경우
              if custom_value.nil? || 
                 custom_value == '' || 
                 (custom_value.is_a?(Array) && custom_value.reject(&:blank?).empty?)
                label = field_config['label'] || field_key
                validation_result[:valid] = false
                validation_result[:field_errors]["custom_fields_#{field_key}"] ||= []
                validation_result[:field_errors]["custom_fields_#{field_key}"] << "#{label} 필수"
                Rails.logger.debug "Validation failed for #{field_key}: empty value"
              end
            # 배열인 경우 (participants 등) 처리
            elsif custom_value.is_a?(Array)
              if custom_value.reject(&:blank?).empty?
                label = field_config['label'] || field_key
                validation_result[:valid] = false
                validation_result[:field_errors]["custom_fields_#{field_key}"] ||= []
                validation_result[:field_errors]["custom_fields_#{field_key}"] << "#{label} 필수"
              end
            # 문자열인 경우
            elsif custom_value.blank? || custom_value.to_s.strip.empty?
              label = field_config['label'] || field_key
              validation_result[:valid] = false
              validation_result[:field_errors]["custom_fields_#{field_key}"] ||= []
              validation_result[:field_errors]["custom_fields_#{field_key}"] << "#{label} 필수"
            end
          end
        end
      end
    end

    # 2. 경비 코드 규칙 검증
    if @expense_code.present?
      # 한도 체크 (에러로 처리)
      if @expense_code.limit_amount.present?
        # 금액이 없으면 0으로 처리
        amount = @expense_item.amount || 0
        limit_amount = @expense_code.limit_amount.to_s.strip
        if limit_amount.match?(/^\d+$/) && limit_amount.to_i > 0
          limit_value = limit_amount.to_i
          if amount > limit_value
            validation_result[:valid] = false
            validation_result[:attachment_errors] << {
              type: 'limit_exceeded',
              message: "경비 한도(#{number_to_currency(limit_value, unit: '₩')})를 초과했습니다."
            }
          end
        end
      end

      # 첨부파일 필수 체크 (먼저 체크)
      if @expense_code.attachment_required? && params[:attachment_ids].blank?
        validation_result[:valid] = false
        validation_result[:attachment_errors] << {
          type: 'attachment_required',
          message: "첨부파일 필수"
        }
      end

      # 승인 규칙 체크
      if @expense_code.expense_code_approval_rules.active.any?
        Rails.logger.info "=== validate_all: 승인 규칙 평가 시작 ==="
        Rails.logger.info "경비 코드: #{@expense_code.name_with_code}"
        Rails.logger.info "금액: #{@expense_item.amount}"
        
        all_rules = @expense_code.expense_code_approval_rules.active.ordered
        Rails.logger.info "전체 활성 규칙 수: #{all_rules.count}"
        
        all_rules.each do |rule|
          Rails.logger.info "  규칙 #{rule.id}: 조건='#{rule.condition}', 그룹='#{rule.approver_group.name}'"
        end
        
        # 현재 사용자가 이미 만족시키지 못하는 규칙만 필터링
        unsatisfied_rules = all_rules.select do |rule|
          condition_result = rule.condition.blank? || rule.evaluate(@expense_item)
          already_satisfied = rule.already_satisfied_by_user?(current_user)
          
          Rails.logger.info "  규칙 #{rule.id} 평가:"
          Rails.logger.info "    - 조건: '#{rule.condition}'"
          Rails.logger.info "    - 조건 평가 결과: #{condition_result}"
          Rails.logger.info "    - 사용자 권한 보유: #{already_satisfied}"
          Rails.logger.info "    - 최종 (조건 충족 && 권한 없음): #{condition_result && !already_satisfied}"
          
          # 조건이 맞고, 사용자가 이미 권한을 가지고 있지 않은 경우만
          condition_result && !already_satisfied
        end
        
        Rails.logger.info "필터링 후 규칙 수: #{unsatisfied_rules.count}"

        if unsatisfied_rules.any?
          required_groups = unsatisfied_rules.map(&:approver_group)
          required_group_names = required_groups.map(&:name).join(', ')
          
          if @approval_line.nil?
            validation_result[:valid] = false
            validation_result[:approval_errors] << {
              type: 'no_approval_line',
              message: "승인 필요: #{required_group_names}"
            }
          else
            # 결재선이 필요 승인 그룹을 포함하는지 확인
            missing_groups = []
            required_groups.each do |group|
              unless @approval_line.approval_line_steps.joins(:approver).where(users: { id: group.members.pluck(:id) }).exists?
                missing_groups << group.name
              end
            end

            if missing_groups.any?
              validation_result[:valid] = false
              validation_result[:approval_errors] << {
                type: 'missing_approvers',
                message: "승인 필요: #{missing_groups.join(', ')}"
              }
            end
          end
        end
        # 사용자가 이미 필요한 권한을 가지고 있는 경우 아무 메시지도 표시하지 않음
      end
    end

    # 메시지 위치를 위해 타입별로 분리된 결과 반환
    render json: validation_result
  end

  # 기존 실시간 필드 검증 (deprecated - validate_all로 대체)
  def validate_field
    # 새 경비 항목 또는 기존 항목 로드
    if params[:id].present?
      @expense_item = @expense_sheet.expense_items.find(params[:id])
      @expense_item.assign_attributes(expense_item_params)
    else
      @expense_item = @expense_sheet.expense_items.build(expense_item_params)
    end

    # 경비 코드가 변경된 경우 관련 데이터 로드
    if params[:expense_item][:expense_code_id].present?
      @expense_code = ExpenseCode.find_by(id: params[:expense_item][:expense_code_id])
      @expense_item.expense_code = @expense_code
    end

    # 검증 수행
    @expense_item.valid?

    # 검증 결과 준비
    validation_result = {
      valid: @expense_item.errors.empty?,
      errors: {},
      validation_messages: []
    }

    # 필드별 에러 메시지
    @expense_item.errors.each do |error|
      field_name = error.attribute.to_s
      validation_result[:errors][field_name] ||= []
      validation_result[:errors][field_name] << error.message
    end
    
    # 커스텀 필드 검증 추가
    if @expense_code.present? && @expense_code.validation_rules.present?
      required_fields = @expense_code.validation_rules['required_fields']
      if required_fields.present?
        Rails.logger.debug "=== Custom fields validation in validate_field ==="
        Rails.logger.debug "Required fields: #{required_fields.inspect}"
        Rails.logger.debug "Custom fields params: #{params[:expense_item][:custom_fields].inspect}"
        
        required_fields.each do |field_key, field_config|
          if field_config['required'] != false
            custom_value = params[:expense_item][:custom_fields]&.[](field_key)
            
            # 멀티셀렉트 필드의 경우 빈 문자열이 배열로 전달될 수 있음
            if field_config['type'] == 'participants' || field_config['type'] == 'organization'
              # FormData에서 빈 값은 [''] 배열로 올 수 있음
              if custom_value.is_a?(Array) && custom_value.length == 1 && custom_value[0] == ''
                custom_value = []
              end
            end
            
            Rails.logger.debug "Field #{field_key}: value=#{custom_value.inspect}, type=#{field_config['type']}"
            
            # type이 participants나 organization인 경우 (멀티셀렉트)
            if field_config['type'] == 'participants' || field_config['type'] == 'organization'
              # 값이 없거나 빈 배열이거나 빈 문자열인 경우
              if custom_value.nil? || 
                 custom_value == '' || 
                 (custom_value.is_a?(Array) && custom_value.reject(&:blank?).empty?)
                label = field_config['label'] || field_key
                validation_result[:valid] = false
                # base 에러로 추가하여 프론트엔드에서 처리
                validation_result[:errors]['base'] ||= []
                validation_result[:errors]['base'] << "#{label} 필수"
                Rails.logger.debug "Validation failed for #{field_key}: empty value"
              end
            # 배열인 경우 (participants 등) 처리
            elsif custom_value.is_a?(Array)
              if custom_value.reject(&:blank?).empty?
                label = field_config['label'] || field_key
                validation_result[:valid] = false
                validation_result[:errors]['base'] ||= []
                validation_result[:errors]['base'] << "#{label} 필수"
              end
            # 문자열인 경우
            elsif custom_value.blank? || custom_value.to_s.strip.empty?
              label = field_config['label'] || field_key
              validation_result[:valid] = false
              validation_result[:errors]['base'] ||= []
              validation_result[:errors]['base'] << "#{label} 필수"
            end
          end
        end
      end
    end

    # 경비 코드 관련 추가 검증 메시지
    if @expense_code.present?
      # 승인 규칙 체크 - 조건에 따라 정보성 메시지와 경고 메시지 구분
      all_rules = @expense_code.expense_code_approval_rules
                               .active
                               .ordered
                               .includes(:approver_group)
      
      # 현재 조건에서 실제로 트리거되는 규칙만 필터링
      triggered_rules = all_rules.select do |rule|
        if rule.condition.blank?
          # 조건이 없으면 항상 필요
          true
        else
          # 조건이 있으면 평가
          rule.evaluate(@expense_item)
        end
      end
      
      # 트리거된 규칙에 대해서만 메시지 생성
      if triggered_rules.any?
        triggered_rules.each do |rule|
          # 조건이 없거나 현재 상태에서 조건을 만족하는 경우에만 메시지 추가
          if rule.condition.blank?
            # 항상 적용되는 규칙
            validation_result[:validation_messages] << "이 경비 코드는 항상 #{rule.approver_group.name} 승인이 필요합니다."
          elsif rule.condition.include?('amount') && @expense_item.amount.present?
            # 금액 조건이 있고, 현재 금액이 입력된 경우
            if rule.condition.match(/>\s*(\d+)/)
              threshold = rule.condition.match(/>\s*(\d+)/)[1].to_i
              if @expense_item.amount > threshold
                validation_result[:validation_messages] << "금액이 #{number_to_currency(threshold, unit: '₩')}을 초과하여 #{rule.approver_group.name} 승인이 필요합니다."
              end
            elsif rule.condition.match(/<\s*(\d+)/)
              threshold = rule.condition.match(/<\s*(\d+)/)[1].to_i
              if @expense_item.amount < threshold
                validation_result[:validation_messages] << "금액이 #{number_to_currency(threshold, unit: '₩')} 미만이므로 #{rule.approver_group.name} 승인이 필요합니다."
              end
            elsif rule.condition.match(/between\s+(\d+)\s+and\s+(\d+)/i)
              matches = rule.condition.match(/between\s+(\d+)\s+and\s+(\d+)/i)
              min_amount = matches[1].to_i
              max_amount = matches[2].to_i
              if @expense_item.amount >= min_amount && @expense_item.amount <= max_amount
                validation_result[:validation_messages] << "금액이 #{number_to_currency(min_amount, unit: '₩')} ~ #{number_to_currency(max_amount, unit: '₩')} 범위이므로 #{rule.approver_group.name} 승인이 필요합니다."
              end
            end
          end
        end
      end

      # 한도 체크 - 명시적으로 한도가 설정된 경우만 체크
      # 빈 문자열, nil, 0은 모두 "한도 없음"으로 처리
      if @expense_code.limit_amount.present? && @expense_item.amount.present?
        limit_amount = @expense_code.limit_amount.to_s.strip
        
        # 숫자가 아니거나 0 이하면 한도 없음으로 처리
        if limit_amount.match?(/^\d+$/) && limit_amount.to_i > 0
          limit_value = limit_amount.to_i
          if @expense_item.amount > limit_value
            validation_result[:validation_messages] << "경비 한도(#{number_to_currency(limit_value, unit: '₩')})를 초과했습니다."
          end
        end
        # 0이거나 빈 값이면 한도 체크 안 함 (한도 없음)
      end

      # 첨부파일 필수 체크 - no_attachments 파라미터나 attachment_ids 확인
      if @expense_code.attachment_required? 
        has_attachments = params[:attachment_ids].present? && !params[:no_attachments].present?
        unless has_attachments
          validation_result[:validation_messages] << "첨부파일 필수"
          validation_result[:valid] = false
        end
      end
    end
    
    # 디버깅 로그
    Rails.logger.debug "=== 검증 결과 ==="
    Rails.logger.debug "valid: #{validation_result[:valid]}"
    Rails.logger.debug "errors: #{validation_result[:errors]}"
    Rails.logger.debug "validation_messages 개수: #{validation_result[:validation_messages].length}"
    Rails.logger.debug "validation_messages: #{validation_result[:validation_messages]}"

    render json: validation_result
  end

  private

  def prepare_approval_lines_data
    # 결재선별 승인자 그룹 정보를 JSON으로 준비
    @approval_lines_data = {}
    
    # 모든 승인자의 그룹 정보를 미리 로드
    approver_ids = @approval_lines.flat_map { |line| line.approval_line_steps.map(&:approver_id) }.uniq
    approvers_with_groups = User.where(id: approver_ids).includes(:approver_groups).index_by(&:id)
    
    @approval_lines.each do |approval_line|
      line_data = {
        id: approval_line.id,
        name: approval_line.name,
        approver_groups: [],
        steps: []  # 승인 단계 상세 정보 추가
      }
      
      # 승인 단계별로 그룹화
      grouped_steps = approval_line.approval_line_steps.ordered.group_by(&:step_order)
      
      grouped_steps.each do |step_order, steps|
        step_data = {
          order: step_order,
          approvers: [],
          approval_type: nil
        }
        
        # 같은 단계의 승인자들 처리
        approvers = steps.select(&:role_approve?)
        
        # 병렬 승인 타입 설정
        if approvers.length >= 2
          step_data[:approval_type] = approvers.first.approval_type
        end
        
        steps.each do |step|
          approver = approvers_with_groups[step.approver_id]
          next unless approver
          
          approver_data = {
            id: approver.id,
            name: approver.name,
            role: step.role,
            groups: []
          }
          
          # 승인자의 그룹 정보
          approver_groups = approver.approver_groups.to_a
          if approver_groups.present?
            highest_group = approver_groups.max_by(&:priority)
            if highest_group
              approver_data[:groups] << {
                id: highest_group.id,
                name: highest_group.name,
                priority: highest_group.priority
              }
            end
          end
          
          step_data[:approvers] << approver_data
        end
        
        line_data[:steps] << step_data
      end
      
      # 각 승인자의 최고 우선순위 그룹 정보 수집 (기존 로직 유지)
      approval_line.approval_line_steps.approvers.includes(approver: :approver_groups).each do |step|
        if step.approver && step.approver.approver_groups.any?
          highest_group = step.approver.approver_groups.max_by(&:priority)
          if highest_group
            # 중복 제거를 위해 그룹 ID를 키로 사용
            existing = line_data[:approver_groups].find { |g| g[:id] == highest_group.id }
            unless existing
              line_data[:approver_groups] << {
                id: highest_group.id,
                name: highest_group.name,
                priority: highest_group.priority
              }
            end
          end
        end
      end
      
      @approval_lines_data[approval_line.id] = line_data
    end
    
    # 현재 사용자의 승인 권한 정보 추가
    @current_user_groups = current_user.approver_groups
                                       .order(priority: :desc)
                                       .map do |group|
      {
        id: group.id,
        name: group.name,
        priority: group.priority
      }
    end
  end
  
  def prepare_expense_codes_data
    # 모든 경비 코드 정보를 JSON으로 준비
    @expense_codes_data = {}
    
    @expense_codes.includes(:expense_code_approval_rules => :approver_group).each do |expense_code|
      # 각 경비 코드에 대한 정보 준비
      code_data = {
        id: expense_code.id,
        name: expense_code.name,
        description: expense_code.description,
        limit_amount: expense_code.limit_amount,
        limit_amount_display: expense_code.limit_amount_display,
        validation_rules: expense_code.validation_rules,
        attachment_required: expense_code.attachment_required?,
        approval_rules: [],
        recent_submission: nil  # 최근 사용 내역 추가
      }
      
      # 승인 규칙 정보
      expense_code.expense_code_approval_rules.active.ordered.each do |rule|
        # condition 파싱하여 타입과 값 추출
        rule_type = nil
        condition_value = nil
        
        if rule.condition.present?
          # "amount > 100000" 형태의 조건을 파싱
          if rule.condition.match(/amount\s*>\s*(\d+)/)
            rule_type = 'amount_greater_than'
            condition_value = $1.to_i
          end
        end
        
        code_data[:approval_rules] << {
          id: rule.id,
          condition: rule.condition,
          rule_type: rule_type,
          condition_value: condition_value,
          group_id: rule.approver_group.id,
          group_name: rule.approver_group.name,
          group_priority: rule.approver_group.priority,
          order: rule.order,
          approver_group: {
            id: rule.approver_group.id,
            name: rule.approver_group.name,
            priority: rule.approver_group.priority
          }
        }
      end
      
      # 최근 사용 내역 조회 (현재 사용자, 해당 경비 코드)
      # 임시저장이 아닌 실제 제출된 항목만 조회
      recent_item = ExpenseItem.joins(:expense_sheet)
                                .where(expense_sheets: { user_id: current_user.id })
                                .where(expense_code_id: expense_code.id)
                                .where(is_draft: false)  # 임시저장 제외
                                .order(created_at: :desc)
                                .first
      
      if recent_item
        code_data[:recent_submission] = {
          custom_fields: recent_item.custom_fields,
          cost_center_id: recent_item.cost_center_id,
          approval_line_id: recent_item.approval_line_id,
          remarks: recent_item.remarks,
          amount: recent_item.amount
        }
      end
      
      @expense_codes_data[expense_code.id] = code_data
    end
  end

  def set_expense_sheet
    if current_user.admin?
      @expense_sheet = ExpenseSheet.find(params[:expense_sheet_id])
    else
      @expense_sheet = current_user.expense_sheets.find(params[:expense_sheet_id])
    end
  end

  def set_expense_item
    @expense_item = @expense_sheet.expense_items
                                    .includes(
                                      approval_request: { 
                                        approval_histories: { 
                                          approver: :organization 
                                        }
                                      }
                                    )
                                    .find(params[:id])
  end

  def check_editable
    unless @expense_sheet.editable?
      redirect_to expense_sheets_path, alert: '수정할 수 없는 상태입니다.'
    end
  end
  
  def expense_item_params
    custom_fields_params = nil
    
    # custom_fields를 동적으로 허용
    if params[:expense_item][:custom_fields].present?
      Rails.logger.info "Processing custom_fields params: #{params[:expense_item][:custom_fields].inspect}"
      custom_fields_params = params[:expense_item][:custom_fields].permit!
      
      # 배열 값을 문자열로 변환
      custom_fields_params.each do |key, value|
        if value.is_a?(Array)
          # 빈 문자열 제거하고 쉼표로 결합
          cleaned_value = value.reject(&:blank?).join(', ')
          custom_fields_params[key] = cleaned_value
          Rails.logger.info "Converted array field '#{key}': #{value.inspect} -> '#{cleaned_value}'"
        end
      end
      Rails.logger.info "Final custom_fields_params: #{custom_fields_params.inspect}"
    end
    
    permitted = params.require(:expense_item).permit(
      :expense_code_id, :cost_center_id, :expense_date, :amount,
      :description, :remarks, :receipt_number, :vendor_name, :vendor_tax_id,
      :lock_version, :approval_line_id,
      :is_budget, :budget_amount, :actual_amount, :excess_reason
    )
    
    # custom_fields 추가
    permitted[:custom_fields] = custom_fields_params if custom_fields_params.present?
    
    # 빈 문자열을 nil로 변환
    permitted[:expense_code_id] = nil if permitted[:expense_code_id].blank?
    permitted[:cost_center_id] = nil if permitted[:cost_center_id].blank?
    
    permitted
  end
  
  def draft_params
    # 임시 저장용 파라미터 (모든 필드 허용)
    params.require(:expense_item).permit!
  end
  
  def check_expense_sheet_editable
    unless @expense_sheet.editable?
      redirect_to expense_sheets_path, alert: '수정할 수 없는 상태입니다.'
    end
  end
  
  def check_item_editable
    unless @expense_item.editable?
      redirect_to expense_sheets_path, alert: '수정할 수 없는 항목입니다.'
    end
  end
end