class Admin::RequestTemplatesController < Admin::BaseController
  before_action :set_request_template, only: [:show, :edit, :update, :destroy, :toggle_active, :duplicate, 
                                               :add_approval_rule, :remove_approval_rule, :toggle_approval_rule, :reorder_approval_rules]
  before_action :set_categories, only: [:new, :edit, :create, :update]

  def index
    @request_templates = RequestTemplate.includes(:request_category)
                                      .ordered
    
    # 카테고리 필터
    if params[:category_id].present?
      @request_templates = @request_templates.where(request_category_id: params[:category_id])
    end
    
    # 상태 필터
    if params[:active].present?
      @request_templates = @request_templates.where(is_active: params[:active] == 'true')
    end
  end

  def show
    @request_forms_count = @request_template.request_forms.count
    @recent_forms = @request_template.request_forms
                                     .includes(:user, :approval_requests)
                                     .order(created_at: :desc)
                                     .limit(5)
  end

  def new
    @request_template = RequestTemplate.new
    @request_template.request_category_id = params[:category_id] if params[:category_id]
  end

  def edit
    @approval_rules = @request_template.request_template_approval_rules.includes(:approver_group).ordered
    @available_groups = ApproverGroup.active.ordered
  end

  def create
    @request_template = RequestTemplate.new(request_template_params)
    
    if @request_template.save
      redirect_to admin_request_template_path(@request_template), 
                  notice: '템플릿이 생성되었습니다.',
                  status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @request_template.update(request_template_params)
      redirect_to admin_request_template_path(@request_template), 
                  notice: '템플릿이 수정되었습니다.',
                  status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @request_template.request_forms.exists?
      redirect_to admin_request_templates_path, 
                  alert: '사용 중인 템플릿은 삭제할 수 없습니다.',
                  status: :see_other
    else
      @request_template.destroy
      redirect_to admin_request_templates_path, 
                  notice: '템플릿이 삭제되었습니다.',
                  status: :see_other
    end
  end

  def toggle_active
    @request_template.update(is_active: !@request_template.is_active)
    redirect_back(fallback_location: admin_request_templates_path,
                  notice: @request_template.is_active ? '템플릿이 활성화되었습니다.' : '템플릿이 비활성화되었습니다.',
                  status: :see_other)
  end

  def duplicate
    new_template = @request_template.dup
    new_template.name = "#{@request_template.name} (복사본)"
    new_template.code = nil # 자동 생성되도록
    
    if new_template.save
      redirect_to edit_admin_request_template_path(new_template),
                  notice: '템플릿이 복제되었습니다.',
                  status: :see_other
    else
      redirect_back(fallback_location: admin_request_templates_path,
                   alert: '템플릿 복제에 실패했습니다.',
                   status: :see_other)
    end
  end

  # 승인 규칙 관련 액션들
  def add_approval_rule
    @approval_rule = @request_template.request_template_approval_rules.build(approval_rule_params)
    
    Rails.logger.debug "Approval rule params: #{approval_rule_params.inspect}"
    Rails.logger.debug "Approval rule valid?: #{@approval_rule.valid?}"
    Rails.logger.debug "Approval rule errors: #{@approval_rule.errors.full_messages}" if @approval_rule.errors.any?
    
    respond_to do |format|
      if @approval_rule.save
        Rails.logger.debug "Approval rule saved successfully: #{@approval_rule.inspect}"
        format.turbo_stream {
          @approval_rules = @request_template.request_template_approval_rules.includes(:approver_group).ordered
          render turbo_stream: turbo_stream.replace(
            'approval_rules_list',
            partial: 'admin/request_templates/approval_rules_list',
            locals: { request_template: @request_template, approval_rules: @approval_rules }
          )
        }
        format.html { redirect_to edit_admin_request_template_path(@request_template), notice: '승인 규칙이 추가되었습니다.' }
      else
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            'flash',
            partial: 'shared/flash',
            locals: { flash: { alert: @approval_rule.errors.full_messages.join(', ') } }
          )
        }
        format.html { redirect_to edit_admin_request_template_path(@request_template), alert: @approval_rule.errors.full_messages.join(', ') }
      end
    end
  end
  
  def remove_approval_rule
    @approval_rule = @request_template.request_template_approval_rules.find(params[:rule_id])
    @approval_rule.destroy
    
    respond_to do |format|
      format.turbo_stream {
        @approval_rules = @request_template.request_template_approval_rules.includes(:approver_group).ordered
        render turbo_stream: turbo_stream.replace(
          'approval_rules_list',
          partial: 'admin/request_templates/approval_rules_list',
          locals: { request_template: @request_template, approval_rules: @approval_rules }
        )
      }
      format.html { redirect_to edit_admin_request_template_path(@request_template), notice: '승인 규칙이 삭제되었습니다.' }
    end
  end
  
  def toggle_approval_rule
    @approval_rule = @request_template.request_template_approval_rules.find(params[:rule_id])
    @approval_rule.update(is_active: !@approval_rule.is_active)
    
    respond_to do |format|
      format.turbo_stream {
        @approval_rules = @request_template.request_template_approval_rules.includes(:approver_group).ordered
        render turbo_stream: turbo_stream.replace(
          'approval_rules_list',
          partial: 'admin/request_templates/approval_rules_list',
          locals: { request_template: @request_template, approval_rules: @approval_rules }
        )
      }
      format.html { redirect_to edit_admin_request_template_path(@request_template) }
    end
  end
  
  def reorder_approval_rules
    params[:rule_ids].each_with_index do |rule_id, index|
      @request_template.request_template_approval_rules.find(rule_id).update(order: index + 1)
    end
    
    head :ok
  end

  private

  def set_request_template
    @request_template = RequestTemplate.find(params[:id])
  end

  def set_categories
    @categories = RequestCategory.active.ordered
  end

  def request_template_params
    # 필드 배열 파라미터 처리
    if params[:request_template][:fields].present?
      params[:request_template][:fields] = process_fields(params[:request_template][:fields])
    end
    
    params.require(:request_template).permit(
      :request_category_id, :name, :description, :is_active
    ).tap do |whitelisted|
      whitelisted[:fields] = params[:request_template][:fields] if params[:request_template][:fields]
    end
  end
  
  def process_fields(fields)
    return [] unless fields.is_a?(Array)
    
    fields.map do |field|
      next if field[:field_key].blank? || field[:field_label].blank?
      
      processed = {
        'field_key' => field[:field_key],
        'field_label' => field[:field_label],
        'field_type' => field[:field_type],
        'is_required' => field[:is_required] == 'true'
      }
      
      if field[:field_options].present? && field[:field_options].first.present?
        processed['field_options'] = field[:field_options].first.split(',').map(&:strip)
      end
      
      processed
    end.compact
  end
  
  def approval_rule_params
    params.require(:request_template_approval_rule).permit(:condition, :approver_group_id, :is_active)
  end
end