class RequestFormsController < ApplicationController
  before_action :require_login
  before_action :set_request_form, only: [:show, :edit, :update, :destroy, :cancel_approval]
  before_action :check_editable, only: [:edit, :update]
  
  def index
    @request_forms = current_user.request_forms.includes(:request_template, :request_category)
                                  .order(created_at: :desc)
                                  .page(params[:page])
  end

  # Step 1: 카테고리 선택
  def select_category
    @categories = RequestCategory.active.ordered
  end

  # Step 2: 템플릿 선택
  def select_template
    @category = RequestCategory.find(params[:category_id])
    @templates = @category.request_templates.active.ordered
  end

  # Step 3: 신청서 작성
  def new
    @template = RequestTemplate.find(params[:template_id])
    @request_form = current_user.request_forms.build(
      request_template: @template,
      request_category: @template.request_category,
      organization: current_user.organization
    )
    
    # 결재선 관련 데이터
    @approval_lines = current_user.approval_lines.active.includes(approval_line_steps: :approver)
    @approval_rules = @template.request_template_approval_rules.active.includes(:approver_group)
    
    # JavaScript에서 사용할 결재선 데이터 준비
    @approval_lines_data = prepare_approval_lines_data(@approval_lines)
    
    # 템플릿의 승인 규칙 정보 전달 (실시간 검증용)
    @template_approval_rules = @approval_rules.map do |rule|
      {
        id: rule.id,
        condition: rule.condition,
        approver_group: rule.approver_group ? {
          id: rule.approver_group.id,
          name: rule.approver_group.name,
          priority: rule.approver_group.priority
        } : nil
      }
    end
    
    # 현재 사용자의 그룹 정보 전달 (경비 항목과 동일)
    @current_user_groups = current_user.approver_groups.map do |group|
      {
        id: group.id,
        name: group.name,
        priority: group.priority
      }
    end
    
    # 초기 결재선 검증 (결재선이 선택되지 않은 상태)
    validate_initial_approval_requirements
  end

  def create
    @template = RequestTemplate.find(params[:request_form][:request_template_id])
    @request_form = current_user.request_forms.build(request_form_params)
    @request_form.request_category = @template.request_category
    @request_form.organization = current_user.organization
    @request_form.status = 'draft'
    
    if @request_form.save
      # 첨부파일 처리
      if params[:request_form][:attachments].present?
        params[:request_form][:attachments].each do |file|
          @request_form.request_form_attachments.create(
            file: file,
            uploaded_by: current_user
          )
        end
      end
      
      # 제출 처리
      if params[:submit_type] == 'submit'
        # 결재선이 이미 선택되어 있으므로 바로 제출 처리
        approval_line = nil
        if @request_form.approval_line_id.present?
          approval_line = current_user.approval_lines.active.find(@request_form.approval_line_id)
        end
        
        # submit_form 메서드 호출 (approval_line 포함)
        submit_form(@request_form, approval_line)
      else
        # 임시 저장 - 편집 페이지로 리다이렉트하여 계속 편집 가능하도록
        redirect_to edit_request_form_path(@request_form), notice: '신청서가 임시저장되었습니다.', status: :see_other
      end
    else
      # 실패 시에도 필요한 데이터 제공
      @approval_lines = current_user.approval_lines.active.includes(approval_line_steps: :approver)
      @approval_rules = @template.request_template_approval_rules.active.includes(:approver_group)
      @approval_lines_data = prepare_approval_lines_data(@approval_lines)
      
      # 템플릿의 승인 규칙 정보 전달
      @template_approval_rules = @approval_rules.map do |rule|
        {
          id: rule.id,
          condition: rule.condition,
          approver_group: rule.approver_group ? {
            id: rule.approver_group.id,
            name: rule.approver_group.name,
            priority: rule.approver_group.priority
          } : nil
        }
      end
      
      # 현재 사용자의 그룹 정보 전달
      @current_user_groups = current_user.approver_groups.map do |group|
        {
          id: group.id,
          name: group.name,
          priority: group.priority
        }
      end
      
      render :new
    end
  end

  def show
    @approval_line = @request_form.approval_line
    @attachments = @request_form.request_form_attachments.includes(:uploaded_by)
  end

  def edit
    @template = @request_form.request_template
    
    # 결재선 관련 데이터
    @approval_lines = current_user.approval_lines.active.includes(approval_line_steps: :approver)
    @approval_rules = @template.request_template_approval_rules.active.includes(:approver_group)
    
    # JavaScript에서 사용할 결재선 데이터 준비
    @approval_lines_data = prepare_approval_lines_data(@approval_lines)
    
    # 템플릿의 승인 규칙 정보 전달 (실시간 검증용)
    @template_approval_rules = @approval_rules.map do |rule|
      {
        id: rule.id,
        condition: rule.condition,
        approver_group: rule.approver_group ? {
          id: rule.approver_group.id,
          name: rule.approver_group.name,
          priority: rule.approver_group.priority
        } : nil
      }
    end
    
    # 현재 사용자의 그룹 정보 전달
    @current_user_groups = current_user.approver_groups.map do |group|
      {
        id: group.id,
        name: group.name,
        priority: group.priority
      }
    end
  end

  def update
    if @request_form.update(request_form_params)
      # 첨부파일 처리
      if params[:request_form][:attachments].present?
        params[:request_form][:attachments].each do |file|
          @request_form.request_form_attachments.create(
            file: file,
            uploaded_by: current_user
          )
        end
      end
      
      # 제출 처리
      if params[:submit_type] == 'submit'
        # 결재선이 이미 선택되어 있으므로 바로 제출 처리
        approval_line = nil
        if @request_form.approval_line_id.present?
          approval_line = current_user.approval_lines.active.find(@request_form.approval_line_id)
        end
        
        # submit_form 메서드 호출 (approval_line 포함)
        submit_form(@request_form, approval_line)
      elsif params[:submit_type] == 'save'
        # 임시 저장 - 편집 페이지에 머물기
        redirect_to edit_request_form_path(@request_form), notice: '신청서가 임시저장되었습니다.', status: :see_other
      else
        redirect_to @request_form, notice: '신청서가 수정되었습니다.', status: :see_other
      end
    else
      @template = @request_form.request_template
      
      # 결재선 관련 데이터 재설정
      @approval_lines = current_user.approval_lines.active.includes(approval_line_steps: :approver)
      @approval_rules = @template.request_template_approval_rules.active.includes(:approver_group)
      @approval_lines_data = prepare_approval_lines_data(@approval_lines)
      
      # 템플릿의 승인 규칙 정보 전달
      @template_approval_rules = @approval_rules.map do |rule|
        {
          id: rule.id,
          condition: rule.condition,
          approver_group: rule.approver_group ? {
            id: rule.approver_group.id,
            name: rule.approver_group.name,
            priority: rule.approver_group.priority
          } : nil
        }
      end
      
      # 현재 사용자의 그룹 정보 전달
      @current_user_groups = current_user.approver_groups.map do |group|
        {
          id: group.id,
          name: group.name,
          priority: group.priority
        }
      end
      
      render :edit
    end
  end

  def destroy
    if @request_form.has_pending_approval?
      redirect_to @request_form, alert: '승인 진행 중인 신청서는 삭제할 수 없습니다. 먼저 승인 요청을 취소해주세요.', status: :see_other
    elsif @request_form.status == 'approved'
      redirect_to @request_form, alert: '승인 완료된 신청서는 삭제할 수 없습니다.', status: :see_other
    else
      @request_form.destroy
      redirect_to request_forms_url, notice: '신청서가 삭제되었습니다.', status: :see_other
    end
  end
  
  # 승인 취소
  def cancel_approval
    if @request_form.cancel_approval_request!
      redirect_to @request_form, notice: '승인 요청이 취소되었습니다. 이제 삭제할 수 있습니다.', status: :see_other
    else
      redirect_to @request_form, alert: '승인 요청 취소에 실패했습니다.', status: :see_other
    end
  end

  
  # 결재선 검증 (AJAX)
  def validate_approval_line
    template = RequestTemplate.find(params[:id])
    approval_line_id = params[:approval_line_id]
    
    # 승인 규칙 확인
    required_groups = template.request_template_approval_rules.active.includes(:approver_group)
    
    if approval_line_id.blank?
      # 결재선이 선택되지 않은 경우
      if required_groups.any?
        render json: {
          valid: false,
          message: '이 템플릿은 결재선이 필요합니다.',
          missing_groups: required_groups.map { |rule| rule.approver_group.name }
        }
      else
        render json: {
          valid: true,
          message: '결재선 없이 제출 가능합니다.'
        }
      end
    else
      # 결재선이 선택된 경우 검증
      approval_line = current_user.approval_lines.active.find_by(id: approval_line_id)
      
      if approval_line.nil?
        render json: {
          valid: false,
          message: '유효하지 않은 결재선입니다.'
        }
        return
      end
      
      # 필수 승인 그룹 체크
      missing_groups = []
      required_groups.each do |rule|
        unless approval_line.has_approver_from_group?(rule.approver_group)
          missing_groups << rule.approver_group.name
        end
      end
      
      if missing_groups.any?
        render json: {
          valid: false,
          message: '다음 승인 그룹이 결재선에 포함되어야 합니다:',
          missing_groups: missing_groups
        }
      else
        render json: {
          valid: true,
          message: '승인 규칙을 모두 충족합니다.'
        }
      end
    end
  end

  private

  def set_request_form
    @request_form = current_user.request_forms.find(params[:id])
  end

  def check_editable
    unless @request_form.draft?
      redirect_to @request_form, alert: '제출된 신청서는 수정할 수 없습니다.'
    end
  end
  
  def validate_initial_approval_requirements
    @approval_validation = {}
    
    if @approval_rules.any?
      # 필수 승인 그룹들
      required_groups = @approval_rules.map { |rule| rule.approver_group.name }
      
      @approval_validation[:type] = 'error'
      @approval_validation[:title] = '승인 필요'
      @approval_validation[:message] = '이 템플릿은 결재선이 필요합니다.'
      @approval_validation[:required_groups] = required_groups
    else
      @approval_validation[:type] = 'warning'
      @approval_validation[:title] = '주의'
      @approval_validation[:message] = '결재선 없이 제출 가능합니다.'
    end
  end
  
  def prepare_approval_lines_data(approval_lines)
    approval_lines.each_with_object({}) do |line, hash|
      line_data = {
        id: line.id,
        name: line.name,
        approver_groups: [],
        steps: []
      }
      
      # 승인 단계별로 그룹화
      grouped_steps = line.approval_line_steps.ordered.includes(approver: :approver_groups).group_by(&:step_order)
      
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
          if step.role_approve?
            approver = step.approver
            approver_data = {
              id: approver.id,
              name: approver.name,
              role: step.role,
              groups: []
            }
            
            # 승인자의 최고 우선순위 그룹만 표시
            if approver.approver_groups.any?
              highest_group = approver.approver_groups.max_by(&:priority)
              if highest_group
                approver_data[:groups] << {
                  id: highest_group.id,
                  name: highest_group.name,
                  priority: highest_group.priority
                }
                
                # 결재선의 전체 그룹에도 추가 (중복 제거)
                unless line_data[:approver_groups].any? { |g| g[:id] == highest_group.id }
                  line_data[:approver_groups] << {
                    id: highest_group.id,
                    name: highest_group.name,
                    priority: highest_group.priority
                  }
                end
              end
            end
            
            step_data[:approvers] << approver_data
          end
        end
        
        line_data[:steps] << step_data
      end
      
      hash[line.id] = line_data
    end
  end

  def request_form_params
    params.require(:request_form).permit(
      :request_template_id,
      :title,
      :approval_line_id,
      form_data: {}
    )
  end

  def submit_form(request_form, approval_line = nil)
    # 승인 규칙에서 필수 승인자 확인 (사용자 권한 고려)
    # TODO: 추후 ExpenseItem과 공통 로직으로 리팩토링 필요 (Approvable concern으로 이동)
    required_groups = request_form.evaluate_approval_rules(current_user)
    
    # 결재선이 없으면 에러 (이제 프론트엔드에서 검증하므로 여기까지 오면 안됨)
    if approval_line.nil? && required_groups.any?
      redirect_to edit_request_form_path(request_form),
                  alert: '결재선을 선택해주세요.',
                  status: :see_other
      return
    end
    
    # 신청서 제출 처리
    request_form.approval_line = approval_line
    
    # submit! 메서드 사용 (RequestForm 모델에 정의되어 있음)
    request_form.submit!
    
    redirect_to request_forms_path, notice: '신청서가 제출되었습니다.', status: :see_other
  end
end
