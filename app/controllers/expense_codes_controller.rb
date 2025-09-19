class ExpenseCodesController < ApplicationController
  before_action :require_login
  
  # Turbo Stream으로 커스텀 필드 렌더링
  def custom_fields
    @expense_code = ExpenseCode.find_by(id: params[:id])
    @expense_item = ExpenseItem.new(expense_code: @expense_code)
    
    # 기존 값들 복원 (validation 실패 후)
    if params[:custom_fields].present?
      @expense_item.custom_fields = params[:custom_fields]
    end
    
    respond_to do |format|
      format.turbo_stream
    end
  end
end