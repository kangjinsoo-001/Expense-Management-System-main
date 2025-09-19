require 'pdf-reader'
require 'tempfile'

# 영수증 분석 및 요약 조율 서비스
class ReceiptAnalyzer
  attr_reader :attachment, :gemini_service, :logger, :attachment_requirement
  
  def initialize(attachment)
    @attachment = attachment
    @gemini_service = GeminiService.new
    @logger = Rails.logger
    @attachment_requirement = find_attachment_requirement
  end
  
  # 영수증 분석 실행
  def analyze!
    return false unless valid_for_analysis?
    
    begin
      # 1단계: 처리 시작 표시
      attachment.update_processing_stage!(:extracting)
      
      # 2단계: 텍스트 추출 (이미 추출된 경우 스킵)
      extract_text_if_needed
      
      # 3단계: AI 요약 처리
      if attachment.extracted_text.present?
        attachment.update_processing_stage!(:summarizing)
        perform_ai_summary
      else
        handle_extraction_failure
      end
      
      true
    rescue => e
      handle_error(e)
      false
    end
  end
  
  # 텍스트만 추출 - 더 이상 필요 없음 (Gemini가 직접 처리)
  def extract_text_only
    # Gemini가 파일을 직접 분석하므로 텍스트 추출 불필요
    logger.info "텍스트 추출 불필요 - Gemini가 파일 직접 분석"
    attachment.update_processing_stage!(:extracted)
  end
  
  # AI 요약만 수행
  def summarize_only
    # 파일을 직접 분석
    attachment.update_processing_stage!(:summarizing)
    perform_ai_summary_with_file
  end
  
  private
  
  def valid_for_analysis?
    attachment.present? && attachment.file.attached?
  end
  
  def extract_text_if_needed
    return if attachment.extracted_text.present?
    
    text = extract_text_from_file
    
    if text.present?
      attachment.update!(
        extracted_text: text,
        processing_stage: ExpenseAttachment::AI_PROCESSING_STAGES[:extracted]
      )
      logger.info "텍스트 추출 완료: Attachment ##{attachment.id}, 길이: #{text.length}"
    else
      raise "텍스트 추출 실패"
    end
  end
  
  def extract_text_from_file
    # Gemini가 파일을 직접 처리하므로 텍스트 추출 불필요
    logger.info "Gemini가 파일을 직적 분석합니다"
    nil
  end
  
  # PDF 처리 - Gemini가 직접 분석
  def extract_text_from_pdf
    logger.info "PDF는 Gemini가 직접 분석합니다"
    nil
  end
  
  # OCR 메서드 제거 - Gemini가 직접 처리
  
  # 이미지 처리 - Gemini가 직접 분석
  def extract_text_from_image
    logger.info "이미지는 Gemini가 직접 분석합니다"
    nil
  end
  
  def clean_extracted_text(text)
    return nil if text.blank?
    
    # 불필요한 공백 및 특수문자 정리
    text.strip
        .gsub(/\r\n/, "\n")
        .gsub(/\n{3,}/, "\n\n")
        .gsub(/[^\w\s가-힣\-.,():\/\[\]{}@#$%&*+=]/u, ' ')
        .squeeze(' ')
  end
  
  # 파일을 직접 분석하는 AI 요약
  def perform_ai_summary_with_file
    return unless attachment.file.attached?
    
    attachment.file.open do |file|
      begin
        # AttachmentRequirement 기반으로 영수증 분석
        if attachment_requirement && attachment_requirement.analysis_rules.active.any?
          # 데이터베이스에서 프롬프트 가져오기
          analysis_rule = attachment_requirement.analysis_rules.active.first
          prompt = analysis_rule.prompt_text
          
          # 파일을 직접 분석 - expense_item 타입으로 전달
          result = gemini_service.analyze_document_file(
            file.path, 
            prompt,
            nil,  # receipt_type
            'expense_item'  # attachment_type
          )
        else
          # 기본 영수증 분석 - expense_item 타입으로 전달
          result = gemini_service.analyze_document_file(
            file.path,
            nil,  # db_prompt (없으면 기본 프롬프트 사용)
            nil,  # receipt_type
            'expense_item'  # attachment_type  
          )
        end
        
        logger.info "분석 결과 전체: #{result.inspect[0..500]}"
        
        if result
          # 결과를 분석하여 영수증 유형 파악
          receipt_type = result['type'] || result[:type] || 'unknown'
          summary = result['data'] || result[:data] || result
          
          logger.info "영수증 유형 분류: #{receipt_type}"
          
          # 요약 성공
          attachment.mark_ai_processed!(summary, receipt_type)
          logger.info "AI 요약 완료: Attachment ##{attachment.id}"
          
          # 요약 결과 로그
          log_summary_result(receipt_type, summary)
          
          # 검증 규칙 실행 (있는 경우)
          run_validation_rules(summary) if attachment_requirement
        else
          logger.warn "AI 분석 실패: Attachment ##{attachment.id}"
          attachment.update!(
            processing_stage: ExpenseAttachment::AI_PROCESSING_STAGES[:failed],
            status: 'failed'
          )
        end
      rescue => e
        logger.error "AI 요약 중 오류: #{e.message}"
        logger.error e.backtrace[0..5].join("\n")
        raise
      end
    end
  end
  
  def perform_ai_summary
    # 기존 메서드는 파일 직접 분석으로 리다이렉트
    perform_ai_summary_with_file
  end
  
  # 기본 영수증 분석 프롬프트
  def build_receipt_analysis_prompt
    <<~PROMPT
      이미지/PDF 문서를 분석하여 정보를 추출하세요.

      1단계: 문서 유형 분류
      - telecom: 통신비 청구서 (SKT, KT, LG U+, 알뜰폰 등)
      - general: 일반 영수증 (식당, 카페, 쇼핑, 교통 등)
      - unknown: 분류 불가능

      2단계: 유형별 데이터 추출

      응답 형식:
      반드시 유효한 JSON 형식으로만 응답하세요.
      마크다운 코드블록(```json```) 없이 순수 JSON만 반환하세요.

      통신비(telecom):
      {
        "type": "telecom",
        "data": {
          "total_amount": 실제 청구 금액,
          "service_charge": 통신 서비스 요금,
          "additional_service_charge": 부가 서비스 요금,
          "device_installment": 단말기 할부금,
          "other_charges": 기타 요금,
          "discount_amount": 할인 금액
        }
      }

      일반 영수증(general):
      {
        "type": "general",
        "data": {
          "store_name": "상호명",
          "location": "주소",
          "total_amount": 숫자값,
          "date": "YYYY-MM-DD",
          "items": [{"name": "품목명", "amount": 숫자값}]
        }
      }

      분류 불가(unknown):
      {
        "type": "unknown",
        "data": {
          "summary_text": "100자 이내 요약"
        }
      }

      중요 규칙:
      - 응답은 파싱 가능한 유효한 JSON이어야 함
      - 금액은 숫자값만 (원, 쉼표 제외)
      - 부가세 처리: 기타 요금이 통신비의 약 10%면 service_charge에 포함
    PROMPT
  end
  
  def handle_extraction_failure
    attachment.update!(
      processing_stage: ExpenseAttachment::AI_PROCESSING_STAGES[:failed],
      status: 'failed'
    )
    logger.error "텍스트 추출 실패: Attachment ##{attachment.id}"
  end
  
  def handle_error(error)
    logger.error "영수증 분석 중 오류 발생: #{error.message}"
    logger.error error.backtrace.join("\n")
    
    attachment.update!(
      processing_stage: ExpenseAttachment::AI_PROCESSING_STAGES[:failed],
      status: 'failed'
    )
    
    # 에러 알림 (추후 구현)
    # NotificationService.notify_admin_error(attachment, error)
  end
  
  def log_summary_result(receipt_type, summary)
    case receipt_type
    when 'telecom'
      logger.info "통신비 영수증 요약:"
      logger.info "- 전체 금액: #{summary[:total_amount]}"
      logger.info "- 서비스 요금: #{summary[:service_charge]}"
      logger.info "- 부가 서비스: #{summary[:additional_service_charge]}"
      logger.info "- 기기 할부: #{summary[:device_installment]}"
    when 'general'
      logger.info "일반 영수증 요약:"
      logger.info "- 상호명: #{summary[:store_name]}"
      logger.info "- 전체 금액: #{summary[:total_amount]}"
      logger.info "- 거래일: #{summary[:date]}"
    else
      logger.info "기타 문서 요약: #{summary[:summary_text]}"
    end
  end
  
  # AttachmentRequirement 찾기
  def find_attachment_requirement
    return nil unless attachment.expense_item
    
    # 경비 항목의 경비 코드 확인
    expense_code = attachment.expense_item.expense_code&.code
    
    # 활성화된 경비 항목용 AttachmentRequirement 찾기
    requirements = AttachmentRequirement.for_expense_items.active.ordered
    
    # 조건식이 일치하는 요구사항 찾기
    requirement = requirements.find do |req|
      if req.condition_expression.present?
        # 간단한 조건 평가 (예: "expense_code == 'TELECOM'")
        if req.condition_expression.include?('expense_code')
          eval_condition = req.condition_expression.gsub('expense_code', "'#{expense_code}'")
          begin
            eval(eval_condition)
          rescue
            false
          end
        else
          true
        end
      else
        true # 조건이 없으면 기본적으로 적용
      end
    end
    
    requirement
  end
  
  # 영수증 타입 결정
  def determine_receipt_type
    # 통합 영수증 분석의 경우 AI가 타입을 결정하도록 함
    # 초기값은 'unknown'으로 설정하고 AI가 분석 중에 결정
    'unknown'
  end
  
  # 검증 규칙 실행
  def run_validation_rules(summary)
    return unless attachment_requirement
    
    validation_rules = attachment_requirement.validation_rules.active
    return if validation_rules.empty?
    
    validation_rules.each do |rule|
      case rule.rule_type
      when 'classification'
        # 분류 검증
        validate_classification(rule, summary)
      when 'amount_validation'
        # 금액 검증
        validate_amount(rule, summary)
      when 'required'
        # 필수 필드 검증
        validate_required_fields(rule, summary)
      end
    end
  rescue => e
    logger.error "검증 규칙 실행 중 오류: #{e.message}"
  end
  
  def validate_classification(rule, summary)
    logger.info "[검증] 분류 검증 실행: #{rule.prompt_text}"
    # 분류 검증 로직 구현
  end
  
  def validate_amount(rule, summary)
    logger.info "[검증] 금액 검증 실행: #{rule.prompt_text}"
    # 금액 검증 로직 구현
  end
  
  def validate_required_fields(rule, summary)
    logger.info "[검증] 필수 필드 검증 실행: #{rule.prompt_text}"
    # 필수 필드 검증 로직 구현
  end
end