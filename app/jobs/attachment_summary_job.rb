# AI를 사용한 첨부파일 요약 백그라운드 작업
class AttachmentSummaryJob < ApplicationJob
  queue_as :low_priority  # AI API 호출은 낮은 우선순위로 처리
  
  # 재시도 설정 (API 제한을 고려하여 더 긴 대기 시간)
  retry_on StandardError, wait: 1.minute, attempts: 3
  retry_on GeminiService::ApiCallError, wait: 5.minutes, attempts: 2
  
  # API 키 없으면 작업 폐기
  discard_on GeminiService::ApiKeyMissingError
  
  # 동시 실행 제한 (API 호출 제한 관리)
  # include GoodJob::ActiveJobExtensions::Concurrency
  # good_job_control_concurrency_with(
  #   total_limit: 5,
  #   key: -> { "gemini_api" }
  # )
  
  def perform(attachment_id, attachment_type = 'ExpenseAttachment')
    attachment = attachment_type.constantize.find_by(id: attachment_id)
    return unless attachment
    
    Rails.logger.info "AI 요약 시작: #{attachment_type} ##{attachment.id}"
    
    # processing_stage가 summarizing이 아니면 업데이트
    if attachment.respond_to?(:processing_stage) && attachment.processing_stage != 'summarizing'
      attachment.update!(processing_stage: 'summarizing')
    end
    
    # 이미 AI 처리된 경우 스킵
    if attachment.respond_to?(:ai_processed?) && attachment.ai_processed?
      Rails.logger.info "이미 AI 처리됨: #{attachment_type} ##{attachment.id}"
      return
    elsif attachment.respond_to?(:analysis_result) && attachment.analysis_result&.dig('ai_processed')
      Rails.logger.info "이미 AI 처리됨: #{attachment_type} ##{attachment.id}"
      return
    end
    
    # Gemini가 파일을 직접 분석하므로 extracted_text 체크 불필요
    # 모든 첨부파일은 파일을 직접 분석
    Rails.logger.info "파일 직접 분석 모드: #{attachment_type} ##{attachment.id}"
    
    # API 호출 제한 체크
    if api_rate_limit_exceeded?
      Rails.logger.warn "API 호출 제한 초과, 5분 후 재시도"
      self.class.set(wait: 5.minutes).perform_later(attachment_id, attachment_type)
      return
    end
    
    # AttachmentRequirement 기반 분석
    if attachment_type == 'ExpenseSheetAttachment'
      # ExpenseSheetAttachment은 AttachmentRequirement의 분석 규칙 사용
      requirement = attachment.attachment_requirement
      analysis_rule = requirement&.analysis_rules&.active&.first if requirement
      
      if analysis_rule && analysis_rule.prompt_text.present?
        # AttachmentAnalysisRule의 프롬프트와 예상 필드 사용
        Rails.logger.info "AttachmentRequirement '#{requirement.name}'의 분석 규칙 사용"
        
        gemini_service = GeminiService.new
        
        # ExpenseSheetAttachment 파일 직접 분석
        if attachment.file.attached?
          attachment.file.open do |file|
            Rails.logger.info "ExpenseSheetAttachment 파일 직접 분석 시작: #{file.path}"
            # attachment_type을 전달하여 적절한 프롬프트 사용
            result = gemini_service.analyze_document_file(
              file.path,
              analysis_rule.prompt_text,
              nil,  # receipt_type
              'expense_sheet'  # attachment_type
            )
            
            if result
              Rails.logger.info "분석 결과 타입: #{result[:type] || result['type']}"
              Rails.logger.info "분석 결과: #{result.inspect[0..500]}"
              attachment.mark_ai_processed!(result)
            else
              Rails.logger.error "파일 분석 실패"
              attachment.mark_as_failed!("AI 분석 실패")
            end
          end
        else
          Rails.logger.error "파일이 첨부되지 않음"
          attachment.mark_as_failed!("파일 없음")
        end
      else
        # 분석 규칙 없는 경우 기본 처리
        Rails.logger.info "분석 규칙 없음, 파일 타입에 맞는 기본 분석 사용"
        if attachment.file.attached?
          attachment.file.open do |file|
            gemini_service = GeminiService.new
            # attachment_type을 전달하여 기본 프롬프트 사용
            result = gemini_service.analyze_document_file(
              file.path, 
              nil,  # db_prompt (없으면 기본 프롬프트 사용)
              nil,  # receipt_type
              'expense_sheet'  # attachment_type
            )
            
            if result
              attachment.mark_ai_processed!(result)
            else
              attachment.mark_as_failed!("AI 분석 실패")
            end
          end
        else
          Rails.logger.error "파일이 첨부되지 않음"
          attachment.mark_as_failed!("파일 없음")
        end
      end
    else
      # ExpenseAttachment은 일반 영수증 분석 사용
      analyzer = ReceiptAnalyzer.new(attachment)
      analyzer.summarize_only
    end
    
    # 처리 결과에 따른 브로드캐스트
    attachment.reload
    
    # AI 처리 여부 확인
    is_processed = if attachment.respond_to?(:ai_processed?)
      attachment.ai_processed?
    else
      attachment.analysis_result&.dig('ai_processed')
    end
    
    if is_processed
      Rails.logger.info "AI 요약 완료: #{attachment_type} ##{attachment.id}"
      broadcast_summary_complete(attachment, attachment_type)
      
      # ExpenseAttachment인 경우에만 경비 항목 업데이트 및 검증
      if attachment_type == 'ExpenseAttachment'
        # 요약 결과를 경비 항목에 자동 반영 (선택적)
        update_expense_item_from_summary(attachment)
        
        # 검증 Job 트리거 (AI 분석 완료 후)
        if attachment.expense_item_id.present?
          ValidationJob.perform_later(attachment.expense_item_id, attachment.id)
          Rails.logger.info "검증 Job 트리거: ExpenseItem ##{attachment.expense_item_id}"
        end
      end
    else
      Rails.logger.warn "AI 요약 실패했지만 텍스트는 사용 가능: #{attachment_type} ##{attachment.id}"
      broadcast_summary_partial(attachment, attachment_type)
    end
  end
  
  private
  
  def api_rate_limit_exceeded?
    # 메트릭 서비스를 통해 API 호출 제한 체크
    metrics = GeminiMetricsService.instance.get_daily_usage
    
    # 일일 제한: 1000 호출 (예시)
    daily_limit = ENV.fetch('GEMINI_DAILY_LIMIT', 1000).to_i
    metrics[:calls] >= daily_limit
  end
  
  def broadcast_summary_complete(attachment, attachment_type = 'ExpenseAttachment')
    # 실시간 업데이트를 위한 Turbo Stream 브로드캐스트
    if attachment_type == 'ExpenseSheetAttachment'
      Turbo::StreamsChannel.broadcast_update_to(
        "sheet_attachment_#{attachment.id}",
        target: "sheet-attachment-#{attachment.id}-status",
        html: "<span class='text-green-600'>AI 분석 완료</span>"
      )
    else
      Turbo::StreamsChannel.broadcast_update_to(
        "attachment_#{attachment.id}",
        target: "attachment_#{attachment.id}_summary",
        partial: "expense_attachments/summary",
        locals: { attachment: attachment }
      )
      
      # 처리 상태 업데이트
      Turbo::StreamsChannel.broadcast_update_to(
        "attachment_#{attachment.id}",
        target: "attachment_#{attachment.id}_status",
        html: "<span class='text-green-600'>요약 완료</span>"
      )
    end
  end
  
  def broadcast_summary_partial(attachment, attachment_type = 'ExpenseAttachment')
    if attachment_type == 'ExpenseSheetAttachment'
      Turbo::StreamsChannel.broadcast_update_to(
        "sheet_attachment_#{attachment.id}",
        target: "sheet-attachment-#{attachment.id}-status",
        html: "<span class='text-yellow-600'>텍스트 추출 완료 (요약 실패)</span>"
      )
    else
      Turbo::StreamsChannel.broadcast_update_to(
        "attachment_#{attachment.id}",
        target: "attachment_#{attachment.id}_status",
        html: "<span class='text-yellow-600'>텍스트 추출 완료 (요약 실패)</span>"
      )
    end
  end
  
  def update_expense_item_from_summary(attachment)
    return unless attachment.expense_item
    return unless attachment.parsed_summary
    
    summary = attachment.parsed_summary
    expense_item = attachment.expense_item
    
    # 영수증 유형에 따른 자동 업데이트
    case attachment.receipt_type
    when 'telecom'
      expense_item.update(
        amount: summary[:total_amount],
        description: "통신비 - #{summary[:billing_month]}",
        category: '통신비'
      ) if summary[:total_amount].present?
    when 'general'
      expense_item.update(
        amount: summary[:total_amount],
        description: "#{summary[:store_name]} - #{summary[:date]}",
        vendor: summary[:store_name]
      ) if summary[:total_amount].present?
    end
    
    Rails.logger.info "경비 항목 자동 업데이트 완료: ExpenseItem ##{expense_item.id}"
  rescue => e
    Rails.logger.error "경비 항목 업데이트 실패: #{e.message}"
  end
end