class Admin::ExpenseSheetApprovalRulesController < Admin::BaseController
  before_action :set_rule, only: [:edit, :update, :destroy, :toggle_active]
  
  def index
    @rules = ExpenseSheetApprovalRule.includes(:approver_group, :submitter_group)
                                     .ordered
    
    respond_to do |format|
      format.html
      format.turbo_stream if turbo_frame_request?
    end
  end
  
  def new
    @rule = ExpenseSheetApprovalRule.new
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def create
    @rule = ExpenseSheetApprovalRule.new(rule_params)
    
    # 조건 생성
    @rule.condition = build_condition
    
    if @rule.save
      respond_to do |format|
        format.html { redirect_to admin_expense_sheet_approval_rules_path, notice: '승인 규칙이 생성되었습니다.' }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("rules-list", partial: "admin/expense_sheet_approval_rules/rule", locals: { rule: @rule }),
            turbo_stream.replace("flash", partial: "shared/flash", locals: { message: '승인 규칙이 생성되었습니다.', type: 'success' })
          ]
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("rule-form", partial: "admin/expense_sheet_approval_rules/form", locals: { rule: @rule })
        end
      end
    end
  end
  
  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def update
    # 조건 업데이트
    @rule.condition = build_condition unless params[:custom_condition].present?
    
    if @rule.update(rule_params)
      respond_to do |format|
        format.html { redirect_to admin_expense_sheet_approval_rules_path, notice: '승인 규칙이 수정되었습니다.' }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("rule_#{@rule.id}", partial: "admin/expense_sheet_approval_rules/rule", locals: { rule: @rule }),
            turbo_stream.replace("flash", partial: "shared/flash", locals: { message: '승인 규칙이 수정되었습니다.', type: 'success' })
          ]
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("rule-form", partial: "admin/expense_sheet_approval_rules/form", locals: { rule: @rule })
        end
      end
    end
  end
  
  def destroy
    @rule.destroy
    
    respond_to do |format|
      format.html { redirect_to admin_expense_sheet_approval_rules_path, notice: '승인 규칙이 삭제되었습니다.' }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("rule_#{@rule.id}"),
          turbo_stream.replace("flash", partial: "shared/flash", locals: { message: '승인 규칙이 삭제되었습니다.', type: 'success' })
        ]
      end
    end
  end
  
  def toggle_active
    @rule.toggle!(:is_active)
    
    respond_to do |format|
      format.html { redirect_to admin_expense_sheet_approval_rules_path }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("rule_#{@rule.id}", partial: "admin/expense_sheet_approval_rules/rule", locals: { rule: @rule })
      end
    end
  end
  
  private
  
  def set_rule
    @rule = ExpenseSheetApprovalRule.find(params[:id])
  end
  
  def rule_params
    params.require(:expense_sheet_approval_rule).permit(
      :approver_group_id, :submitter_group_id, :rule_type, 
      :order, :is_active, :organization_id, :submitter_condition
    )
  end
  
  def build_condition
    case params[:expense_sheet_approval_rule][:rule_type]
    when 'total_amount'
      operator = params[:amount_operator]
      amount = params[:amount_threshold]
      return nil if operator.blank? || amount.blank?
      "#총금액 #{operator} #{amount}"
    when 'item_count'
      operator = params[:count_operator]
      count = params[:count_threshold]
      return nil if operator.blank? || count.blank?
      "#항목수 #{operator} #{count}"
    when 'expense_code_based'
      codes = params[:expense_codes]
      return nil if codes.blank?
      "#경비코드:#{codes.join(',')}"
    when 'submitter_based'
      # 제출자 기반은 submitter_group_id로 처리
      nil
    else
      params[:custom_condition]
    end
  end
end