class Admin::ExpenseCodesController < Admin::BaseController
  include TurboCacheControl
  
  before_action :set_expense_code, only: [:show, :edit, :update, :destroy, :add_approval_rule, :remove_approval_rule, :update_approval_rule_order, :update_approval_rules_order]

  def index
    # Turbo 캐시 문제 방지
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
    
    @expense_codes = ExpenseCode.current
                               .includes(:organization)
                               .left_joins(:parent_code)
                               .order(Arel.sql('COALESCE(expense_codes.parent_code_id, expense_codes.id), expense_codes.version'))
  end

  def show
    # Turbo 캐시 문제 방지
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
    
    # 승인 규칙 관련 데이터 로드
    @approval_rules = @expense_code.expense_code_approval_rules.includes(:approver_group).ordered
    @available_groups = ApproverGroup.active.order(priority: :desc)
  end

  def new
    @expense_code = ExpenseCode.new
    @approval_rules = []
    @available_groups = ApproverGroup.all
  end

  def create
    @expense_code = ExpenseCode.new(expense_code_params)
    
    if @expense_code.save
      respond_to do |format|
        format.html { redirect_to admin_expense_codes_path, notice: '경비 코드가 생성되었습니다.', status: :see_other }
        format.turbo_stream do
          redirect_to admin_expense_codes_path, notice: '경비 코드가 생성되었습니다.', status: :see_other
        end
      end
    else
      @approval_rules = []
      @available_groups = ApproverGroup.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @approval_rules = @expense_code.expense_code_approval_rules.includes(:approver_group).ordered
    @available_groups = ApproverGroup.active.order(priority: :desc)
  end

  def update
    # 디버깅: 요청 메소드 확인
    Rails.logger.info "Update action called with method: #{request.method}"
    Rails.logger.info "Params: #{params.inspect}"
    
    # 기존 경비 항목이 있는지 확인
    has_expense_items = @expense_code.expense_items.exists?
    
    # 필드 변경 확인을 위한 기존 필드 저장
    old_fields = @expense_code.required_fields.deep_dup if @expense_code.required_fields.is_a?(Hash)
    
    if has_expense_items && significant_changes?(expense_code_params)
      # 기존 항목이 있고 중요한 변경사항이 있으면 새 버전 생성
      begin
        new_version = @expense_code.create_new_version!(expense_code_params)
        
        respond_to do |format|
          format.html { 
            redirect_to admin_expense_codes_path, notice: '경비 코드가 수정되었습니다.', status: :see_other 
          }
          format.turbo_stream do
            # show 페이지에서 왔는지 확인
            if request.referer&.include?("/admin/expense_codes/#{@expense_code.id}")
              # 리스트 페이지로 리다이렉트
              redirect_to admin_expense_codes_path, notice: '경비 코드가 수정되었습니다.', status: :see_other
            else
              # 이전 버전 삭제하고 새 버전 추가
              render turbo_stream: [
                turbo_stream.remove(@expense_code),
                turbo_stream.append('expense_codes', partial: 'admin/expense_codes/expense_code', locals: { expense_code: new_version }),
                turbo_stream.replace('modal', ''),
                turbo_stream.replace('flash', 
                  partial: 'shared/flash',
                  locals: { flash: { notice: '경비 코드가 수정되었습니다.' } })
              ]
            end
          end
        end
      rescue => e
        @expense_code.errors.add(:base, "새 버전 생성 실패: #{e.message}")
        render :edit, status: :unprocessable_entity
      end
    else
      # 기존 항목이 없거나 중요하지 않은 변경은 그대로 업데이트
      # 하지만 is_current가 true인 경우 버전 충돌을 피하기 위해 reload
      @expense_code.reload if @expense_code.is_current
      
      # 필드 변경 시 템플릿과 한도 자동 업데이트
      if old_fields && expense_code_params[:validation_rules] && expense_code_params[:validation_rules]['required_fields']
        new_fields = expense_code_params[:validation_rules]['required_fields']
        @expense_code.assign_attributes(expense_code_params)
        @expense_code.update_template_and_limit_on_field_change!(old_fields, new_fields)
        
        if @expense_code.save
          respond_to do |format|
            format.html { 
              redirect_to admin_expense_codes_path, notice: '경비 코드가 수정되었습니다.', status: :see_other 
            }
            format.turbo_stream do
              # 리스트 페이지로 리다이렉트
              redirect_to admin_expense_codes_path, notice: '경비 코드가 수정되었습니다.', status: :see_other
            end
          end
        else
          respond_to do |format|
            format.html { render :edit, status: :unprocessable_entity }
            format.turbo_stream { render :edit, status: :unprocessable_entity }
          end
        end
      else
        # 필드 변경이 없는 일반 업데이트
        if @expense_code.update(expense_code_params)
          respond_to do |format|
            format.html { 
              redirect_to admin_expense_codes_path, notice: '경비 코드가 수정되었습니다.', status: :see_other 
            }
            format.turbo_stream do
              # 리스트 페이지로 리다이렉트
              redirect_to admin_expense_codes_path, notice: '경비 코드가 수정되었습니다.', status: :see_other
            end
          end
        else
          respond_to do |format|
            format.html { render :edit, status: :unprocessable_entity }
            format.turbo_stream { render :edit, status: :unprocessable_entity }
          end
        end
      end
    end
  end

  def destroy
    @expense_code.destroy
    
    respond_to do |format|
      format.html { redirect_to admin_expense_codes_path, notice: '경비 코드가 삭제되었습니다.', status: :see_other }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(@expense_code),
          turbo_stream.replace('flash', 
            partial: 'shared/flash',
            locals: { flash: { notice: '경비 코드가 삭제되었습니다.' } })
        ]
      end
    end
  end
  
  # 승인 규칙 추가
  def add_approval_rule
    rule_params = approval_rule_params
    # order가 params에 포함되어 있으면 제거
    rule_params.delete(:order)
    
    @approval_rule = @expense_code.expense_code_approval_rules.build(rule_params)
    # order는 모델의 before_validation에서 자동 설정됨
    
    if @approval_rule.save
      @expense_code.reload
      @approval_rules = @expense_code.expense_code_approval_rules.includes(:approver_group).ordered
      @available_groups = ApproverGroup.active.order(priority: :desc)
      
      respond_to do |format|
        format.html { 
          # referer가 edit 페이지에서 왔으면 edit 페이지로, 아니면 show 페이지로
          if request.referer&.include?("/edit")
            redirect_to edit_admin_expense_code_path(@expense_code), notice: '승인 규칙이 추가되었습니다.'
          else
            redirect_to admin_expense_code_path(@expense_code), notice: '승인 규칙이 추가되었습니다.'
          end
        }
        format.turbo_stream # add_approval_rule.turbo_stream.erb 렌더링
      end
    else
      @approval_rules = @expense_code.expense_code_approval_rules.includes(:approver_group).ordered
      @available_groups = ApproverGroup.active.order(priority: :desc)
      
      respond_to do |format|
        format.html { render 'show', status: :unprocessable_entity }
        format.turbo_stream {
          render turbo_stream: turbo_stream.prepend('dragdrop_flash_container', 
            partial: 'shared/inline_flash_message',
            locals: { type: 'alert', message: @approval_rule.errors.full_messages.join(', ') })
        }
      end
    end
  end
  
  # 승인 규칙 삭제
  def remove_approval_rule
    @approval_rule = @expense_code.expense_code_approval_rules.find(params[:rule_id])
    @approval_rule.destroy
    
    # 남은 규칙들을 다시 로드
    @expense_code.reload
    @approval_rules = @expense_code.expense_code_approval_rules.includes(:approver_group).ordered
    @available_groups = ApproverGroup.active.order(priority: :desc)
    
    respond_to do |format|
      format.html { 
        # referer가 edit 페이지에서 왔으면 edit 페이지로, 아니면 show 페이지로
        if request.referer&.include?("/edit")
          redirect_to edit_admin_expense_code_path(@expense_code), notice: '승인 규칙이 삭제되었습니다.'
        else
          redirect_to admin_expense_code_path(@expense_code), notice: '승인 규칙이 삭제되었습니다.'
        end
      }
      format.turbo_stream # remove_approval_rule.turbo_stream.erb 렌더링
    end
  end
  
  # 승인 규칙 순서 변경
  def update_approval_rule_order
    @approval_rule = @expense_code.expense_code_approval_rules.find(params[:rule_id])
    
    if @approval_rule.update(order: params[:order])
      respond_to do |format|
        format.html { redirect_to admin_expense_code_path(@expense_code), notice: '승인 규칙 순서가 변경되었습니다.' }
        format.turbo_stream {
          @approval_rules = @expense_code.expense_code_approval_rules.includes(:approver_group).ordered
          
          render turbo_stream: [
            turbo_stream.replace("approval_rules_list",
              partial: "admin/expense_codes/approval_rules_list",
              locals: { expense_code: @expense_code, approval_rules: @approval_rules }
            ),
            turbo_stream.replace('flash_container', 
              partial: 'shared/inline_flash_message',
              locals: { type: :notice, message: '승인 규칙 순서가 변경되었습니다.' })
          ]
        }
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_expense_code_path(@expense_code), alert: '순서 변경에 실패했습니다.' }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace('flash_container', 
            partial: 'shared/inline_flash_message',
            locals: { type: :alert, message: '순서 변경에 실패했습니다.' })
        }
      end
    end
  end
  
  # 승인 규칙들의 순서를 일괄 업데이트
  def update_approval_rules_order
    rules_params = params.require(:rules)
    
    ActiveRecord::Base.transaction do
      rules_params.each do |rule_data|
        rule = @expense_code.expense_code_approval_rules.find(rule_data[:id])
        rule.update!(order: rule_data[:order])
      end
    end
    
    respond_to do |format|
      format.json { render json: { success: true, message: '승인 규칙 순서가 변경되었습니다.' } }
    end
  rescue => e
    respond_to do |format|
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def set_expense_code
    @expense_code = ExpenseCode.find(params[:id])
  end

  def expense_code_params
    # validation_rules 내의 required_fields를 JSON으로 받아서 처리
    permitted = params.require(:expense_code).permit(
      :code, :name, :description, :limit_amount, :active, :organization_id, :description_template, :attachment_required,
      validation_rules: {},  # validation_rules를 permit에 추가
      expense_code_approval_rules_attributes: [:id, :approver_group_id, :min_amount, :max_amount, :is_mandatory, :_destroy]
    )
    
    # 한도 없음 체크박스 처리
    if params[:no_limit] == '1'
      permitted[:limit_amount] = nil
    end
    
    # validation_rules 처리
    if params[:expense_code][:validation_rules].present?
      validation_rules = {}
      
      # required_fields가 JSON 문자열로 전달된 경우 파싱
      if params[:expense_code][:validation_rules][:required_fields].present?
        validation_rules['required_fields'] = JSON.parse(params[:expense_code][:validation_rules][:required_fields])
      end
      
      permitted[:validation_rules] = validation_rules
    end
    
    # approval_process_config 처리
    if params[:expense_code][:approval_process_config].present?
      permitted[:approval_process_config] = JSON.parse(params[:expense_code][:approval_process_config])
    end
    
    permitted
  end
  
  def significant_changes?(new_params)
    # validation_rules나 limit_amount 변경은 중요한 변경으로 간주
    current_rules = @expense_code.validation_rules || {}
    new_rules = new_params[:validation_rules] || {}
    
    # validation_rules 비교
    return true if current_rules != new_rules
    
    # limit_amount 비교 (NULL 값 처리 포함)
    current_limit = @expense_code.limit_amount
    new_limit = new_params[:limit_amount].present? ? new_params[:limit_amount].to_f : nil
    
    # NULL과 0은 다른 값으로 처리
    if current_limit.nil? != new_limit.nil?
      return true
    elsif current_limit && new_limit && current_limit != new_limit
      return true
    end
    
    false
  end
  
  def approval_rule_params
    params.require(:expense_code_approval_rule).permit(:condition, :approver_group_id, :is_active)
  end
end
