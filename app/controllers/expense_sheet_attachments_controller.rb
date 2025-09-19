# 경비 시트 첨부파일 관리 컨트롤러
class ExpenseSheetAttachmentsController < ApplicationController
  before_action :require_login
  before_action :set_expense_sheet
  before_action :set_attachment, only: [:show, :destroy, :status, :analyze]
  
  def index
    @attachments = @expense_sheet.expense_sheet_attachments
                                  .includes(:attachment_requirement)
                                  .order(created_at: :desc)
    
    # 필수 첨부파일 요구사항 확인
    @required_attachments = AttachmentRequirement.where(
      attachment_type: 'expense_sheet',
      required: true,
      active: true
    ).order(:position)
    
    # 이미 업로드된 요구사항 ID 목록
    @uploaded_requirement_ids = @attachments.pluck(:attachment_requirement_id).compact
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def new
    @attachment = @expense_sheet.expense_sheet_attachments.build
    @attachment_requirements = AttachmentRequirement.where(
      attachment_type: 'expense_sheet',
      active: true
    ).order(:position)
  end
  
  def create
    @attachment = @expense_sheet.expense_sheet_attachments.build(attachment_params)
    
    # AttachmentRequirement 자동 연결 (법인카드 명세서)
    if @attachment.attachment_requirement_id.blank?
      requirement = AttachmentRequirement.for_expense_sheets.active.first
      @attachment.attachment_requirement_id = requirement.id if requirement
    end
    
    if @attachment.save
      # 텍스트 추출 및 AI 분석 작업은 모델의 after_create_commit 콜백에서 자동으로 처리됨
      
      respond_to do |format|
        format.json do
          render json: {
            id: @attachment.id,
            file_name: @attachment.file_name,
            status: @attachment.status,
            processing_stage: @attachment.processing_stage
          }
        end
        format.turbo_stream # create.turbo_stream.erb를 렌더링
        format.html { redirect_to expense_sheet_expense_sheet_attachments_path(@expense_sheet) }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @attachment.errors.full_messages }, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "flash",
            partial: "shared/flash",
            locals: { type: :alert, message: @attachment.errors.full_messages.join(', ') }
          )
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end
  
  def show
    # 파일 미리보기 또는 다운로드
    if @attachment.file.attached?
      redirect_to rails_blob_url(@attachment.file, disposition: 'inline')
    else
      redirect_back(fallback_location: expense_sheet_expense_sheet_attachments_path(@expense_sheet),
                   alert: '파일을 찾을 수 없습니다.')
    end
  end
  
  def destroy
    @attachment.destroy
    
    respond_to do |format|
      format.json { head :no_content }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("sheet-attachment-#{@attachment.id}"),
          turbo_stream.update("upload-status",
            partial: "expense_sheet_attachments/upload_status",
            locals: { expense_sheet: @expense_sheet })
        ]
      end
      format.html { 
        redirect_to expense_sheet_expense_sheet_attachments_path(@expense_sheet),
                    notice: '첨부파일이 삭제되었습니다.'
      }
    end
  end
  
  def status
    # analysis_result 내의 summary_data를 파싱된 형태로 전달
    analysis_result = @attachment.analysis_result || {}
    if analysis_result['summary_data'].present?
      begin
        # summary_data가 문자열이면 파싱
        if analysis_result['summary_data'].is_a?(String)
          analysis_result['summary_data'] = JSON.parse(analysis_result['summary_data'])
        end
      rescue JSON::ParserError
        # 파싱 실패시 그대로 유지
      end
    end
    
    render json: {
      id: @attachment.id,
      status: @attachment.status,
      processing_stage: @attachment.processing_stage,
      status_label: @attachment.status_label,
      extracted_text: @attachment.extracted_text,
      analysis_result: analysis_result,
      validation_result: @attachment.validation_result,
      validation_summary: @attachment.validation_summary,
      ai_processed: analysis_result['ai_processed']
    }
  end
  
  # AI 분석 수동 트리거
  def analyze
    if @attachment.file.attached?
      @attachment.mark_as_analyzing!
      SheetTextExtractionJob.perform_later(@attachment.id, 'ExpenseSheetAttachment')
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "sheet-attachment-#{@attachment.id}-status",
            partial: "expense_sheet_attachments/analysis_status",
            locals: { attachment: @attachment }
          )
        end
        format.json { render json: { message: 'AI 분석이 시작되었습니다.' } }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "sheet-attachment-#{@attachment.id}-status",
            html: '<span class="text-red-600">파일이 없습니다</span>'
          )
        end
        format.json { render json: { error: '파일이 첨부되지 않았습니다.' }, status: :unprocessable_entity }
      end
    end
  end
  
  private
  
  def set_expense_sheet
    @expense_sheet = current_user.expense_sheets.find(params[:expense_sheet_id])
  end
  
  def set_attachment
    @attachment = @expense_sheet.expense_sheet_attachments.find(params[:id])
  end
  
  def attachment_params
    params.require(:expense_sheet_attachment).permit(:file, :attachment_requirement_id)
  end
end