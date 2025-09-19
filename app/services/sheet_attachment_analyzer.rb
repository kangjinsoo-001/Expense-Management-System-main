# 경비 시트 첨부파일 분석 서비스
class SheetAttachmentAnalyzer
  attr_reader :attachment, :gemini_service
  
  def initialize(attachment)
    @attachment = attachment
    @gemini_service = GeminiService.new
  end
  
  def analyze
    return false unless attachment.file.attached?
    
    begin
      # 법인카드 명세서는 파일을 직접 Gemini로 분석
      if attachment.attachment_requirement&.name == "법인카드 명세서"
        Rails.logger.info "법인카드 명세서 직접 분석: ExpenseSheetAttachment ##{attachment.id}"
        
        # AttachmentSummaryJob이 파일을 직접 분석하도록 트리거
        # extracted_text 없이 바로 AI 분석 단계로
        attachment.update!(
          processing_stage: 'processing',
          status: 'processing'
        )
        
        # AI 분석 Job 트리거
        AttachmentSummaryJob.perform_later(attachment.id, 'ExpenseSheetAttachment')
      else
        # 다른 첨부파일 유형은 기존 방식 유지 (향후 변경 가능)
        extracted_text = extract_text_from_file
        
        if extracted_text.blank?
          attachment.mark_as_failed!("텍스트를 추출할 수 없습니다")
          return false
        end
        
        attachment.update!(
          analysis_result: { 'extracted_text' => extracted_text }
        )
        
        Rails.logger.info "텍스트 추출 완료, AI 요약 대기중: ExpenseSheetAttachment ##{attachment.id}"
      end
      
      true
    rescue => e
      Rails.logger.error "Sheet attachment analysis failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      attachment.mark_as_failed!(e.message)
      false
    end
  end
  
  private
  
  def extract_text_from_file
    return nil unless attachment.file.attached?
    
    # 파일을 임시로 다운로드
    attachment.file.open do |file|
      case attachment.file_type
      when 'pdf'
        extract_text_from_pdf(file)
      when 'jpg', 'jpeg', 'png'
        extract_text_from_image(file)
      else
        Rails.logger.warn "Unsupported file type: #{attachment.file_type}"
        nil
      end
    end
  end
  
  def extract_text_from_pdf(file)
    # PDF는 Gemini가 직접 처리하므로 텍스트 추출 불필요
    Rails.logger.info "PDF 파일은 Gemini가 직접 분석합니다"
    nil
  rescue => e
    Rails.logger.error "PDF processing failed: #{e.message}"
    nil
  end
  
  def extract_text_from_image(file)
    # 이미지도 Gemini가 직접 처리하므로 텍스트 추출 불필요
    Rails.logger.info "이미지 파일은 Gemini가 직접 분석합니다"
    nil
  rescue => e
    Rails.logger.error "Image processing failed: #{e.message}"
    nil
  end
  
  # OCR 메서드 제거 - Gemini가 직접 PDF/이미지 처리
  
  def clean_extracted_text(text)
    return nil if text.blank?
    
    # 불필요한 공백 및 특수문자 정리
    text.strip
        .gsub(/\r\n/, "\n")
        .gsub(/\n{3,}/, "\n\n")
        .gsub(/[^\w\s가-힣\-.,():\/\[\]{}@#$%&*+=]/u, ' ')
        .squeeze(' ')
  end
  
  def analyze_with_requirement(extracted_text)
    requirement = attachment.attachment_requirement
    analysis_rule = requirement.attachment_analysis_rules.active.first
    
    return basic_analysis(extracted_text) unless analysis_rule
    
    # Gemini API로 분석
    prompt = build_analysis_prompt(extracted_text, analysis_rule)
    response = gemini_service.analyze_text(prompt)
    
    if response[:success]
      # 분석 결과 저장
      analysis_result = parse_analysis_response(response[:content], analysis_rule.expected_fields)
      attachment.update!(
        analysis_result: analysis_result,
        extracted_text: extracted_text
      )
      
      # 검증 규칙 적용
      apply_validation_rules(analysis_result) if requirement.attachment_validation_rules.active.any?
    else
      attachment.update!(
        extracted_text: extracted_text,
        validation_result: { error: response[:error] }
      )
    end
  end
  
  def basic_analysis(extracted_text)
    # 기본 분석 (텍스트만 저장)
    attachment.update!(
      extracted_text: extracted_text,
      analysis_result: {
        text_length: extracted_text.length,
        analyzed_at: Time.current
      }
    )
  end
  
  def build_analysis_prompt(text, analysis_rule)
    <<~PROMPT
      다음 문서를 분석하여 요청된 정보를 추출해주세요.
      
      분석 규칙:
      #{analysis_rule.prompt_text}
      
      문서 내용:
      #{text}
      
      JSON 형식으로 응답해주세요. 추출할 수 없는 필드는 null로 표시하세요.
      예상 필드: #{analysis_rule.expected_fields.keys.join(', ')}
    PROMPT
  end
  
  def parse_analysis_response(response_text, expected_fields)
    # JSON 응답 파싱
    begin
      json_match = response_text.match(/\{.*\}/m)
      return {} unless json_match
      
      parsed = JSON.parse(json_match[0])
      
      # 예상 필드만 필터링
      result = {}
      expected_fields.each do |field, type|
        value = parsed[field] || parsed["data"]&.dig(field)
        result[field] = cast_value(value, type) if value.present?
      end
      
      result
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse AI response: #{e.message}"
      {}
    end
  end
  
  def cast_value(value, type)
    case type
    when 'number'
      value.to_s.gsub(/[^\d.-]/, '').to_f
    when 'date'
      Date.parse(value.to_s) rescue value
    when 'boolean'
      ['true', '1', 'yes', '예'].include?(value.to_s.downcase)
    else
      value.to_s
    end
  end
  
  def apply_validation_rules(analysis_result)
    requirement = attachment.attachment_requirement
    validation_results = []
    
    requirement.attachment_validation_rules.active.each do |rule|
      case rule.rule_type
      when 'required'
        # 필수 필드 검증
        if analysis_result.blank?
          validation_results << {
            rule: rule.prompt_text,
            passed: false,
            severity: rule.severity,
            message: "필수 정보를 추출할 수 없습니다."
          }
        end
        
      when 'amount_match'
        # 금액 일치 검증 (경비 시트 총액과 비교)
        if analysis_result['total_amount'].present?
          sheet_total = attachment.expense_sheet.expense_items.sum(:amount)
          attachment_total = analysis_result['total_amount'].to_f
          
          if (sheet_total - attachment_total).abs > 0.01
            validation_results << {
              rule: rule.prompt_text,
              passed: false,
              severity: rule.severity,
              message: "첨부파일 금액(#{number_to_currency(attachment_total)})과 경비 시트 총액(#{number_to_currency(sheet_total)})이 일치하지 않습니다."
            }
          else
            validation_results << {
              rule: rule.prompt_text,
              passed: true,
              severity: rule.severity
            }
          end
        end
        
      when 'order_match'
        # 순서 일치 검증
        validation_results << {
          rule: rule.prompt_text,
          passed: true,
          severity: rule.severity,
          message: "순서 검증은 수동으로 확인이 필요합니다."
        }
      end
    end
    
    # 검증 결과 저장
    passed = validation_results.all? { |r| r[:passed] != false || r[:severity] == 'info' }
    attachment.update!(
      validation_result: {
        passed: passed,
        results: validation_results,
        validated_at: Time.current
      }
    )
  end
  
  def number_to_currency(amount)
    "₩#{amount.to_i.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')}"
  end
end