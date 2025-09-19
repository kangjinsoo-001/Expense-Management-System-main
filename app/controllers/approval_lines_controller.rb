class ApprovalLinesController < ApplicationController
  before_action :require_login
  before_action :set_approval_line, only: [:show, :edit, :update, :destroy, :toggle_active, :preview]
  before_action :check_owner, only: [:edit, :update, :destroy, :toggle_active]

  def index
    @approval_lines = current_user.approval_lines
                                  .active  # 삭제되지 않은 결재선만 표시
                                  .includes(approval_line_steps: [:approver])
                                  .ordered_by_position
  end

  def show
    @approval_steps = @approval_line.approval_line_steps
                                   .includes(:approver)
                                   .ordered
    # 단계별로 그룹화
    @grouped_steps = @approval_steps.group_by(&:step_order)
  end

  def new
    @approval_line = current_user.approval_lines.build
    @users = User.where.not(id: current_user.id).includes(:organization).order(:name)
    # 빈 결재선 단계 추가하지 않음 - 사용자가 "단계 추가" 버튼을 눌렀을 때만 추가
  end

  def create
    @approval_line = current_user.approval_lines.build(approval_line_params)

    if @approval_line.save
      redirect_to approval_lines_path, notice: '결재선이 생성되었습니다.', status: :see_other
    else
      @users = User.where.not(id: current_user.id).includes(:organization).order(:name)
      # 기존 입력된 approval_line_steps 데이터가 이미 approval_line_params를 통해 설정되어 있음
      # 추가 build는 하지 않음
      # 단계별로 그룹화 (삭제 예정이거나 승인자가 없는 항목 제외)
      @grouped_steps = @approval_line.approval_line_steps
                                     .reject { |step| step.marked_for_destruction? || step.approver_id.blank? }
                                     .group_by(&:step_order)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @users = User.where.not(id: current_user.id).includes(:organization).order(:name)
    # 단계별로 그룹화된 승인자들 (삭제 예정이거나 승인자가 없는 항목 제외)
    @grouped_steps = @approval_line.approval_line_steps
                                   .reject { |step| step.marked_for_destruction? || step.approver_id.blank? }
                                   .group_by(&:step_order)
  end

  def update
    if @approval_line.update(approval_line_params)
      redirect_to approval_line_path(@approval_line), notice: '결재선이 수정되었습니다.', status: :see_other
    else
      @users = User.where.not(id: current_user.id).includes(:organization).order(:name)
      # 기존 approval_line_steps 데이터 유지를 위해 다시 할당
      @approval_line.assign_attributes(approval_line_params)
      # 단계별로 그룹화 (삭제 예정이거나 승인자가 없는 항목 제외)
      @grouped_steps = @approval_line.approval_line_steps
                                     .reject { |step| step.marked_for_destruction? || step.approver_id.blank? }
                                     .group_by(&:step_order)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # 소프트 삭제 처리
    @approval_line.update(deleted_at: Time.current)
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(dom_id(@approval_line)),
          turbo_stream.remove("#{dom_id(@approval_line)}_card"),
          turbo_stream.prepend("flash-messages",
            partial: "shared/flash",
            locals: { message: "결재선이 삭제되었습니다.", type: "notice" })
        ]
      end
      format.html { redirect_to approval_lines_path, notice: '결재선이 삭제되었습니다.', status: :see_other }
    end
  end

  def toggle_active
    @approval_line.update(is_active: !@approval_line.is_active)
    
    respond_to do |format|
      format.turbo_stream do
        # 데스크톱과 모바일 뷰 모두 업데이트
        render turbo_stream: [
          turbo_stream.replace(
            dom_id(@approval_line),
            partial: 'approval_lines/approval_line_row',
            locals: { approval_line: @approval_line }
          ),
          turbo_stream.replace(
            "#{dom_id(@approval_line)}_card",
            partial: 'approval_lines/approval_line_card',
            locals: { approval_line: @approval_line }
          )
        ]
      end
      format.html { redirect_to approval_lines_path, status: :see_other }
    end
  end
  
  def preview
    respond_to do |format|
      format.turbo_stream do
        render partial: 'approval_lines/preview', locals: { approval_line: @approval_line }
      end
      format.html do
        render partial: 'approval_lines/preview', 
               locals: { approval_line: @approval_line },
               layout: false
      end
      format.json do
        render json: {
          html: render_to_string(partial: 'approval_lines/preview', locals: { approval_line: @approval_line })
        }
      end
    end
  end
  
  def reorder
    ApprovalLine.reorder_for_user(current_user, params[:approval_line_ids])
    
    respond_to do |format|
      format.json { render json: { success: true } }
      format.turbo_stream { head :ok }
    end
  rescue => e
    respond_to do |format|
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      format.turbo_stream { head :unprocessable_entity }
    end
  end

  private

  def set_approval_line
    @approval_line = ApprovalLine.find(params[:id])
  end

  def check_owner
    unless @approval_line.user == current_user
      redirect_to approval_lines_path, alert: '권한이 없습니다.', status: :see_other
    end
  end

  def approval_line_params
    permitted = params.require(:approval_line).permit(
      :name, 
      :is_active,
      approval_line_steps_attributes: [
        :id, :approver_id, :step_order, :role, :approval_type, :_destroy
      ]
    )
    
    # name 필드 trim 처리
    permitted[:name] = permitted[:name].strip if permitted[:name].present?
    
    permitted
  end
end