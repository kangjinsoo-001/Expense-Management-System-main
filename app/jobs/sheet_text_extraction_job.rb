# 경비 시트 첨부파일에서 텍스트를 추출하는 백그라운드 작업
class SheetTextExtractionJob < ApplicationJob
  queue_as :default
  
  # 재시도 설정 (지수 백오프: 3초, 18초, 114초)
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(attachment_id, attachment_type = 'ExpenseSheetAttachment')
    attachment = attachment_type.constantize.find_by(id: attachment_id)
    return unless attachment
    
    Rails.logger.info "텍스트 추출 Job 시작: #{attachment_type} ##{attachment.id}"
    
    # 이미 분석 완료된 경우 스킵
    if attachment.completed?
      Rails.logger.info "이미 분석 완료됨: #{attachment_type} ##{attachment.id}"
      return
    end
    
    # processing_stage를 summarizing으로 업데이트 (ExpenseAttachment와 통일)
    attachment.update!(
      processing_stage: 'summarizing',
      status: 'processing'
    )
    
    # Gemini가 파일을 직접 분석하므로 텍스트 추출 단계는 불필요
    # 바로 AI 요약 Job으로 이동
    Rails.logger.info "Gemini 직접 분석을 위해 AI 요약 Job으로 이동: #{attachment_type} ##{attachment.id}"
    AttachmentSummaryJob.perform_later(attachment.id, attachment_type)
    
    # Turbo Streams로 실시간 업데이트
    broadcast_processing_started(attachment)
  end
  
  private
  
  def broadcast_processing_started(attachment)
    # 실시간 업데이트를 위한 Turbo Stream 브로드캐스트
    Turbo::StreamsChannel.broadcast_update_to(
      "sheet_attachment_#{attachment.id}",
      target: "sheet-attachment-#{attachment.id}-status",
      html: "<span class='text-blue-600'>AI 분석 중...</span>"
    )
  end
  
  def broadcast_analysis_complete(attachment)
    # 실시간 업데이트를 위한 Turbo Stream 브로드캐스트
    Turbo::StreamsChannel.broadcast_update_to(
      "sheet_attachment_#{attachment.id}",
      target: "sheet-attachment-#{attachment.id}-status",
      partial: "expense_sheet_attachments/analysis_status",
      locals: { attachment: attachment }
    )
    
    # 전체 업로드 상태 업데이트
    Turbo::StreamsChannel.broadcast_update_to(
      "expense_sheet_#{attachment.expense_sheet_id}",
      target: "upload-status",
      partial: "expense_sheet_attachments/upload_status",
      locals: { expense_sheet: attachment.expense_sheet }
    )
  end
  
  def broadcast_analysis_failed(attachment)
    Turbo::StreamsChannel.broadcast_update_to(
      "sheet_attachment_#{attachment.id}",
      target: "sheet-attachment-#{attachment.id}-status",
      html: "<span class='text-red-600'>분석 실패</span>"
    )
  end
end