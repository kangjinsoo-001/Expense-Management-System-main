# 첨부파일에서 텍스트를 추출하는 백그라운드 작업
class TextExtractionJob < ApplicationJob
  queue_as :default
  
  # 재시도 설정 (지수 백오프: 3초, 18초, 114초)
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  # 실행 시간 제한
  # discard_on ActiveJob::DeserializationError
  
  def perform(attachment_id)
    attachment = ExpenseAttachment.find_by(id: attachment_id)
    return unless attachment
    
    Rails.logger.info "텍스트 추출 Job 시작: Attachment ##{attachment.id}"
    
    # processing_stage를 summarizing으로 업데이트
    attachment.update!(
      processing_stage: 'summarizing',
      status: 'processing'
    )
    
    # Gemini가 파일을 직접 분석하므로 텍스트 추출 단계는 불필요
    # 바로 AI 요약 Job으로 이동
    Rails.logger.info "Gemini 직접 분석을 위해 AI 요약 Job으로 이동: Attachment ##{attachment.id}"
    AttachmentSummaryJob.perform_later(attachment.id)
    
    # Turbo Streams로 실시간 업데이트
    broadcast_processing_started(attachment)
  end
  
  private
  
  def broadcast_processing_started(attachment)
    # 실시간 업데이트를 위한 Turbo Stream 브로드캐스트
    Turbo::StreamsChannel.broadcast_update_to(
      "attachment_#{attachment.id}",
      target: "attachment_#{attachment.id}_status",
      html: "<span class='text-blue-600'>AI 분석 중...</span>"
    )
  end
end