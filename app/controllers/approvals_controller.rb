class ApprovalsController < ApplicationController
  before_action :require_login
  before_action :set_approval_request, only: [:show, :approve, :reject]
  before_action :check_approval_permission, only: [:approve, :reject]

  def index
    # 현재 활성 탭 파라미터 (기본값: approval-needed)
    @active_tab = params[:tab] || 'approval-needed'
    
    # Turbo Frame 요청인 경우 프레임만 렌더링
    if turbo_frame_request_id == "approvals_tabs"
      # Turbo Frame만 업데이트
    end
    
    # 전체 목록 - 내가 요청했거나 내가 결재선에 있는 항목만
    # 1. 내가 올린 요청의 ID들 (경비와 신청서 모두 포함)
    expense_request_ids = ApprovalRequest.joins("INNER JOIN expense_items ON approval_requests.approvable_id = expense_items.id AND approval_requests.approvable_type = 'ExpenseItem'")
                                         .joins("INNER JOIN expense_sheets ON expense_items.expense_sheet_id = expense_sheets.id")
                                         .where(expense_sheets: { user_id: current_user.id })
                                         .pluck(:id)
    
    form_request_ids = ApprovalRequest.joins("INNER JOIN request_forms ON approval_requests.approvable_id = request_forms.id AND approval_requests.approvable_type = 'RequestForm'")
                                      .where(request_forms: { user_id: current_user.id })
                                      .pluck(:id)
    
    my_requested_ids = expense_request_ids + form_request_ids
    
    # 2. 내가 결재선에 있는 요청의 ID들 (승인자 또는 참조자)
    in_approval_line_ids = ApprovalRequest.joins(approval_line: :approval_line_steps)
                                          .where(approval_line_steps: { approver_id: current_user.id })
                                          .pluck(:id)
    
    # 두 배열을 합치고 중복 제거
    all_request_ids = (my_requested_ids + in_approval_line_ids).uniq
    
    # ID 목록으로 쿼리 - polymorphic eager loading 추가
    @all_requests = ApprovalRequest.where(id: all_request_ids)
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
                                   .order(created_at: :desc)
                                   .page(params[:all_page])
                                   .per(50)
    
    # 내가 올린 승인 요청 목록 (경비와 신청서 모두)
    @my_requests = ApprovalRequest.where(id: my_requested_ids)
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
                                 .order(created_at: :desc)
                                 .page(params[:my_page])
                                 .per(50)
    
    # 승인 필요 목록 (내가 승인해야 할 항목)
    @approval_requests = ApprovalRequest.for_approver(current_user)
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
                                      .order(created_at: :desc)
                                      .page(params[:approval_page])
                                      .per(50)
    
    # 참조자로 지정된 항목들
    @reference_requests = ApprovalRequest.joins(approval_line: :approval_line_steps)
                                       .where(approval_line_steps: { approver_id: current_user.id, role: 'reference' })
                                       .where(status: 'pending')
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
                                       .distinct
                                       .order(created_at: :desc)
                                       .page(params[:reference_page])
                                       .per(50)
  end

  def show
    @approvable = @approval_request.approvable
    
    # 타입에 따른 추가 데이터 로드
    if @approvable.is_a?(ExpenseItem)
      @expense_item = @approvable
      @expense_attachments = @expense_item.expense_attachments
      is_owner = @expense_item.expense_sheet.user_id == current_user.id
    elsif @approvable.is_a?(RequestForm)
      @request_form = @approvable
      @request_attachments = @request_form.request_form_attachments
      is_owner = @request_form.user_id == current_user.id
    end
    
    @approval_histories = @approval_request.approval_histories
                                        .includes(:approver)
                                        .order(created_at: :desc)
    
    # 권한 확인 - 승인 프로세스에 포함된 사용자인지 확인
    is_in_approval_process = @approval_request.approval_line
                                             .approval_line_steps
                                             .where(approver_id: current_user.id)
                                             .exists?
    
    # 권한이 없는 경우
    unless is_in_approval_process || is_owner || current_user.admin?
      redirect_to approvals_path, alert: '해당 승인 건에 대한 권한이 없습니다.'
      return
    end
    
    # 승인/참조 권한 확인
    @can_approve = @approval_request.can_be_approved_by?(current_user)
    @can_view = @approval_request.can_be_viewed_by?(current_user)
    
    # 참조자인 경우 열람 기록 남기기
    @approval_request.record_view(current_user) if @can_view
    
    # Turbo Fresh Visit 강제 (캐시 사용 안함)
    fresh_when(etag: [@approval_request, @approvable, Time.current.to_i])
  end

  def approve
    if @approval_request.process_approval(current_user, params[:comment])
      redirect_to approvals_path, notice: '승인 처리되었습니다.'
    else
      redirect_to approval_path(@approval_request), alert: @approval_request.errors.full_messages.first
    end
  end

  def reject
    if @approval_request.process_rejection(current_user, params[:comment])
      redirect_to approvals_path, notice: '반려 처리되었습니다.'
    else
      redirect_to approval_path(@approval_request), alert: @approval_request.errors.full_messages.first
    end
  rescue ArgumentError => e
    redirect_to approval_path(@approval_request), alert: e.message
  end

  def batch_approve
    approval_ids = params[:approval_ids] || []
    success_count = 0
    failed_count = 0
    errors = []
    
    approval_ids.each do |id|
      request = ApprovalRequest.find_by(id: id)
      
      # approvable(ExpenseItem 또는 RequestForm) 존재 여부 검증
      if request && request.approvable.present? && request.can_be_approved_by?(current_user)
        if request.process_approval(current_user, '일괄 승인')
          success_count += 1
        else
          failed_count += 1
          errors << "ID #{id}: #{request.errors.full_messages.join(', ')}"
        end
      else
        failed_count += 1
        if request && !request.approvable.present?
          errors << "ID #{id}: 승인 대상 항목이 삭제되었습니다"
        else
          errors << "ID #{id}: 승인 권한이 없습니다"
        end
      end
    end
    
    respond_to do |format|
      format.html do
        if success_count > 0
          redirect_to approvals_path, notice: "#{success_count}건이 성공적으로 승인되었습니다."
        else
          redirect_to approvals_path, alert: '승인 처리할 수 있는 항목이 없습니다.'
        end
      end
      
      format.json do
        if success_count > 0
          render json: { 
            success: true, 
            message: "#{success_count}건이 성공적으로 승인되었습니다.", 
            success_count: success_count,
            failed_count: failed_count,
            errors: errors
          }
        else
          render json: { 
            success: false, 
            message: '승인 처리할 수 있는 항목이 없습니다.', 
            errors: errors 
          }, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_approval_request
    @approval_request = ApprovalRequest.includes(
      :approvable,
      approval_line: { approval_line_steps: :approver }
    ).find(params[:id])
    
    # 타입별 추가 인클루드 처리
    if @approval_request.approvable_type == 'ExpenseItem' && @approval_request.approvable
      @approval_request.approvable = ExpenseItem.includes(
        :expense_code, 
        :cost_center,
        expense_sheet: :user
      ).find(@approval_request.approvable_id)
    elsif @approval_request.approvable_type == 'RequestForm' && @approval_request.approvable
      @approval_request.approvable = RequestForm.includes(
        :user,
        :request_template
      ).find(@approval_request.approvable_id)
    end
  end

  def check_approval_permission
    unless @approval_request.can_be_approved_by?(current_user)
      redirect_to approvals_path, alert: '승인 권한이 없습니다.'
    end
  end
end