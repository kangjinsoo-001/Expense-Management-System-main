class Admin::AttachmentRequirementsController < Admin::BaseController
  before_action :set_attachment_requirement, only: [:show, :edit, :update, :destroy]
  
  def index
    # 경비 항목용과 경비 시트용 요구사항을 분리하여 가져오기
    @expense_item_requirements = AttachmentRequirement.for_expense_items
                                                      .includes(:analysis_rules, :validation_rules)
                                                      .ordered
    
    @expense_sheet_requirements = AttachmentRequirement.for_expense_sheets
                                                       .includes(:analysis_rules, :validation_rules)
                                                       .ordered
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @analysis_rules = @attachment_requirement.analysis_rules.order(:created_at)
    @validation_rules = @attachment_requirement.validation_rules.order(:position)
  end

  def new
    @attachment_requirement = AttachmentRequirement.new
    @attachment_requirement.analysis_rules.build
    @attachment_requirement.validation_rules.build
  end

  def edit
    # 폼 표시를 위해 빈 규칙 추가 (없는 경우)
    @attachment_requirement.analysis_rules.build if @attachment_requirement.analysis_rules.empty?
    @attachment_requirement.validation_rules.build if @attachment_requirement.validation_rules.empty?
  end

  def create
    @attachment_requirement = AttachmentRequirement.new(attachment_requirement_params)
    
    if @attachment_requirement.save
      redirect_to admin_attachment_requirements_path, 
                  notice: '첨부파일 요구사항이 생성되었습니다.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @attachment_requirement.update(attachment_requirement_params)
      redirect_to admin_attachment_requirement_path(@attachment_requirement), 
                  notice: '첨부파일 요구사항이 수정되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @attachment_requirement.destroy
    redirect_to admin_attachment_requirements_path, 
                notice: '첨부파일 요구사항이 삭제되었습니다.'
  end

  private

  def set_attachment_requirement
    @attachment_requirement = AttachmentRequirement.find(params[:id])
  end

  def attachment_requirement_params
    params.require(:attachment_requirement).permit(
      :name, :description, :required, :active, :position,
      :attachment_type, :condition_expression, file_types: [],
      analysis_rules_attributes: [:id, :prompt_text, :expected_fields, :active, :_destroy],
      validation_rules_attributes: [:id, :rule_type, :prompt_text, :severity, :position, :active, :_destroy]
    )
  end
end
