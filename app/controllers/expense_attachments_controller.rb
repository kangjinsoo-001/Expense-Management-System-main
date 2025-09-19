class ExpenseAttachmentsController < ApplicationController
  before_action :set_expense_item
  before_action :set_attachment, only: [:show, :destroy, :status, :extract_text, :summarize]
  
  def index
    @attachments = @expense_item.expense_attachments.order(created_at: :desc)
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  def upload_modal
    @expense_item = ExpenseItem.find_by(id: params[:expense_item_id])
    render layout: false
  end
  
  def upload_and_extract
    attachment = ExpenseAttachment.new(attachment_params)
    
    if attachment.save
      # 파일 정보 저장
      if attachment.file.attached?
        attachment.update(
          file_name: attachment.file.filename.to_s,
          file_type: attachment.file.content_type,
          file_size: attachment.file.byte_size,
          status: 'processing',
          processing_stage: 'extracting'
        )
        
        # 텍스트 추출 작업 시작 (백그라운드 작업) - AI 요약 포함
        TextExtractionJob.perform_later(attachment.id)
      end
      
      render json: {
        id: attachment.id,
        status: attachment.status,
        extracted_text: attachment.extracted_text,
        metadata: attachment.metadata
      }
    else
      render json: { error: attachment.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def create
    @attachment = @expense_item.expense_attachments.build(attachment_params)
    
    if @attachment.save
      # 파일 정보 저장
      if @attachment.file.attached?
        @attachment.update(
          file_name: @attachment.file.filename.to_s,
          file_type: @attachment.file.content_type,
          file_size: @attachment.file.byte_size,
          status: 'processing',
          processing_stage: 'pending'
        )
        
        # 텍스트 추출 작업 시작 - AI 요약 포함
        TextExtractionJob.perform_later(@attachment.id)
      end
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("attachments-list", 
              partial: "expense_attachments/attachment", 
              locals: { attachment: @attachment }),
            turbo_stream.replace("attachment-form",
              partial: "expense_attachments/form",
              locals: { expense_item: @expense_item, attachment: ExpenseAttachment.new })
          ]
        end
        format.html { redirect_to expense_item_expense_attachments_path(@expense_item) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "attachment-form",
            partial: "expense_attachments/form",
            locals: { expense_item: @expense_item, attachment: @attachment }
          )
        end
        format.html { render :index }
      end
    end
  end
  
  def show
    # 파일 미리보기 또는 다운로드
    if @attachment.file.attached?
      redirect_to rails_blob_url(@attachment.file, disposition: 'inline')
    else
      redirect_back(fallback_location: expense_item_expense_attachments_path(@expense_item),
                   alert: '파일을 찾을 수 없습니다.')
    end
  end
  
  def destroy
    @attachment.destroy
    
    respond_to do |format|
      format.json { head :no_content }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("attachment-#{@attachment.id}")
      end
      format.html { 
        if @expense_item
          redirect_to expense_item_expense_attachments_path(@expense_item)
        else
          redirect_back(fallback_location: root_path)
        end
      }
    end
  end
  
  def status
    # summary_data를 파싱된 형태로 전달
    parsed_summary = if @attachment.summary_data.present?
      begin
        JSON.parse(@attachment.summary_data)
      rescue JSON::ParserError
        @attachment.summary_data
      end
    else
      nil
    end
    
    render json: {
      id: @attachment.id,
      status: @attachment.status,
      processing_stage: @attachment.processing_stage,
      extracted_text: @attachment.extracted_text,
      metadata: @attachment.metadata,
      ai_processed: @attachment.ai_processed,
      receipt_type: @attachment.receipt_type,
      summary_data: parsed_summary
    }
  end
  
  # 텍스트 추출 수동 트리거
  def extract_text
    TextExtractionJob.perform_later(@attachment.id)
    
    respond_to do |format|
      format.turbo_stream do
        @attachment.update!(processing_stage: 'extracting')
        render turbo_stream: turbo_stream.update(
          "attachment_#{@attachment.id}_status",
          partial: "expense_attachments/extraction_status",
          locals: { attachment: @attachment }
        )
      end
      format.json { render json: { message: '텍스트 추출이 시작되었습니다.' } }
    end
  end
  
  # AI 요약 수동 트리거
  def summarize
    AttachmentSummaryJob.perform_later(@attachment.id)
    
    respond_to do |format|
      format.turbo_stream do
        @attachment.update!(processing_stage: 'summarizing')
        render turbo_stream: turbo_stream.update(
          "attachment_#{@attachment.id}_status",
          partial: "expense_attachments/extraction_status",
          locals: { attachment: @attachment }
        )
      end
      format.json { render json: { message: 'AI 요약이 시작되었습니다.' } }
    end
  end
  
  # AI 요약 HTML 반환 (재사용을 위한 엔드포인트)
  def summary_html
    @attachment = ExpenseAttachment.find(params[:id])
    
    render partial: 'expense_attachments/summary', 
           locals: { attachment: @attachment },
           layout: false
  end
  
  private
  
  def set_expense_item
    @expense_item = ExpenseItem.find_by(id: params[:expense_item_id])
  end
  
  def set_attachment
    if @expense_item
      @attachment = @expense_item.expense_attachments.find(params[:id])
    else
      @attachment = ExpenseAttachment.find(params[:id])
    end
  end
  
  def attachment_params
    params.require(:attachment).permit(:file) rescue params.require(:expense_attachment).permit(:file)
  end
  
  # 더미 데이터 메서드는 제거됨 - ExtractTextFromAttachmentJob을 사용합니다
end
