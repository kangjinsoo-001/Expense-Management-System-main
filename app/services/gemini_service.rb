require 'net/http'
require 'json'
require 'uri'
require 'base64'

# Gemini AI API 서비스
class GeminiService
  class GeminiError < StandardError; end
  class ApiKeyMissingError < GeminiError; end
  class ApiCallError < GeminiError; end
  
  attr_reader :api_key, :logger, :metrics_service
  
  def initialize
    @logger = Rails.logger
    @metrics_service = GeminiMetricsService.instance
    @api_key = Rails.configuration.gemini_api_key
    
    raise ApiKeyMissingError, "Gemini API 키가 설정되지 않았습니다" unless @api_key.present?
    
    # 모델 설정 로그
    @logger.info "Gemini 서비스 초기화 - 모델: #{GeminiConfig::MODEL}"
  end
  
  # 영수증을 분석하여 분류와 요약을 한번에 수행
  def analyze_receipt(text)
    return nil if text.blank?
    
    prompt = build_unified_prompt(text)
    
    # thinking 토큰을 제한했으므로 output 토큰만 충분히 설정
    response = call_api(prompt, temperature: GeminiConfig::TEMPERATURE, max_tokens: 1000)
    result = parse_unified_response(response)
    
    # 메트릭 추적
    metrics_service.track_classification(result[:receipt_type])
    metrics_service.track_summary(result[:summary].present?)
    
    result
  rescue => e
    logger.error "영수증 분석 실패: #{e.message}"
    logger.error e.backtrace.join("\n")
    metrics_service.track_summary(false)
    { receipt_type: 'unknown', summary: nil }
  end
  
  # AttachmentRequirement 기반 영수증 분석
  def analyze_receipt_with_rules(text, prompt: nil, expected_fields: nil, receipt_type: 'unknown')
    return nil if text.blank?
    
    # 프롬프트가 제공되면 해당 프롬프트 사용, 아니면 기본 프롬프트 사용
    if prompt.present?
      final_prompt = build_dynamic_prompt(text, prompt, expected_fields, receipt_type)
    else
      final_prompt = build_unified_prompt(text)
    end
    
    # 법인카드 명세서는 더 많은 토큰 필요
    max_tokens = (receipt_type == 'corporate_card') ? 5000 : 1000  # 모든 거래를 위해 증가
    response = call_api(final_prompt, temperature: GeminiConfig::TEMPERATURE, max_tokens: max_tokens)
    result = parse_dynamic_response(response, expected_fields, receipt_type)
    
    # 메트릭 추적
    metrics_service.track_classification(result[:receipt_type])
    metrics_service.track_summary(result[:summary].present?)
    
    result
  rescue => e
    logger.error "AttachmentRequirement 기반 영수증 분석 실패: #{e.message}"
    logger.error e.backtrace.join("\n")
    metrics_service.track_summary(false)
    { receipt_type: receipt_type, summary: nil }
  end
  # 경비 검증을 위한 AI 분석 메서드
  # Flash 모델로 빠른 검증 (단계별 검증용)
  def analyze_for_validation_flash(validation_prompt)
    return nil if validation_prompt.blank?
    
    begin
      prompt = build_validation_prompt(validation_prompt)
      
      # Flash 모델 사용 - 더 적은 토큰으로 빠른 처리
      # call_api는 이제 { response: ..., token_usage: ... } 형태로 반환
      result = call_api(prompt, temperature: 0.1, max_tokens: 2000)
      
      # response와 token_usage 분리
      text_response = result[:response]
      token_usage = result[:token_usage]
      
      # JSON 응답 파싱
      parsed_response = parse_validation_response(text_response)
      
      # 토큰 사용량 정보 추가
      if token_usage
        parsed_response['token_usage'] = {
          'total_tokens' => token_usage[:total_tokens],
          'prompt_tokens' => token_usage[:prompt_tokens],
          'completion_tokens' => token_usage[:completion_tokens]
        }
      end
      
      parsed_response
    rescue => e
      logger.error "Flash 모델 검증 실패: #{e.message}"
      logger.error e.backtrace.first(5).join("\n")
      nil
    end
  end
  
  def analyze_for_validation(validation_prompt)
    return nil if validation_prompt.blank?
    
    begin
      # 검증용 프롬프트는 이미 구조화되어 있으므로 그대로 사용
      prompt = build_validation_prompt(validation_prompt)
      
      # 검증은 더 많은 토큰이 필요할 수 있음 (특히 많은 경비 항목이 있을 때)
      # max_tokens를 충분히 늘려서 응답이 잘리지 않도록 함
      # Gemini Pro는 더 많은 토큰 지원 (최대 32768)
      
      # Flash 모델 사용 (기본) - 최대 토큰: 8192
      # response = call_api(prompt, temperature: 0.1, max_tokens: 8192)
      
      # Pro 모델 사용 - 더 많은 토큰으로 설정 (16384)
      result = call_api_for_validation(prompt, temperature: 0.1, max_tokens: 16384)
      
      # response와 token_usage 분리
      response = result[:response]
      token_usage = result[:token_usage]
      
      # JSON 응답 파싱
      parsed_response = parse_validation_response(response)
      
      # 토큰 사용량 정보 추가
      parsed_response['token_usage'] = token_usage if token_usage
      
      parsed_response
    rescue => e
      logger.error "경비 검증 AI 분석 실패: #{e.message}"
      logger.error e.backtrace.first(5).join("\n")
      
      # 오류 시 기본 응답 반환
      {
        'validation_summary' => '검증 중 오류가 발생했습니다.',
        'all_valid' => false,
        'validation_details' => [],
        'issues_found' => ["AI 검증 중 오류 발생: #{e.message}"],
        'recommendations' => []
      }
    end
  end
  
  # PDF/이미지 파일을 직접 분석하는 메서드
  def analyze_document_file(file_path, db_prompt = nil, receipt_type = nil, attachment_type = nil)
    return nil unless File.exist?(file_path)
    
    begin
      # 파일 타입 확인
      file_extension = File.extname(file_path).downcase
      mime_type = case file_extension
                  when '.pdf' then 'application/pdf'
                  when '.jpg', '.jpeg' then 'image/jpeg'
                  when '.png' then 'image/png'
                  else
                    raise "지원하지 않는 파일 형식: #{file_extension}"
                  end
      
      # 파일 크기 체크 (20MB 제한)
      file_size = File.size(file_path)
      if file_size > 20 * 1024 * 1024
        raise "파일 크기가 20MB를 초과합니다: #{file_size / 1024 / 1024}MB"
      end
      
      # 파일을 Base64로 인코딩
      file_data = File.read(file_path, mode: 'rb')
      base64_data = Base64.strict_encode64(file_data)
      
      # 프롬프트 생성 - attachment_type에 따라 분기
      if db_prompt.present?
        # DB 프롬프트가 있을 때 - 타입 정보 추가
        enhanced_prompt = build_type_enhanced_prompt(db_prompt, attachment_type)
        final_prompt = build_final_prompt_with_json_rules(enhanced_prompt)
      else
        # DB 프롬프트가 없을 때 - attachment_type에 따른 기본 프롬프트 사용
        base_prompt = build_base_prompt_for_type(attachment_type)
        final_prompt = build_final_prompt_with_json_rules(base_prompt)
      end
      
      # corporate_card는 더 많은 토큰 필요
      max_tokens = 3000
      
      # Multimodal API 호출
      response = call_multimodal_api(base64_data, mime_type, final_prompt, max_tokens: max_tokens)
      
      # JSON 응답 파싱
      parse_dynamic_response(response, nil, receipt_type)
    rescue => e
      logger.error "문서 파일 분석 실패: #{e.message}"
      logger.error e.backtrace.first(5).join("\n")
      nil
    end
  end
  
  
  private
  
  # attachment_type에 따른 타입 정보 추가된 프롬프트 생성
  def build_type_enhanced_prompt(db_prompt, attachment_type)
    if attachment_type == 'expense_sheet'
      # expense_sheet는 법인카드 전용
      <<~PROMPT
        ## 문서 타입
        이 문서는 법인카드 명세서입니다.
        응답에 반드시 "type": "corporate_card" 필드를 포함하세요.
        
        ## 사용자 요청사항
        #{db_prompt}
      PROMPT
    elsif attachment_type == 'expense_item'
      # expense_item은 일반 문서 (telecom, general, unknown)
      <<~PROMPT
        ## 문서 타입 분류
        다음 3가지 타입 중 하나로 분류하세요:
        1. telecom: 통신비 청구서 (SKT, KT, LG U+)
        2. general: 일반 영수증 (식당, 카페, 쇼핑)
        3. unknown: 분류 불가
        
        응답에 반드시 "type" 필드를 포함하세요.
        
        ## 사용자 요청사항
        #{db_prompt}
      PROMPT
    else
      # 기본: 모든 타입 가능
      <<~PROMPT
        ## 문서 타입 분류
        다음 4가지 타입 중 하나로 분류하세요:
        1. corporate_card: 법인카드 명세서 (거래내역이 테이블 형태)
        2. telecom: 통신비 청구서 (SKT, KT, LG U+)
        3. general: 일반 영수증 (식당, 카페, 쇼핑)
        4. unknown: 분류 불가
        
        응답에 반드시 "type" 필드를 포함하세요.
        
        ## 사용자 요청사항
        #{db_prompt}
      PROMPT
    end
  end
  
  # attachment_type에 따른 기본 프롬프트 생성 (DB 프롬프트 없을 때)
  def build_base_prompt_for_type(attachment_type)
    if attachment_type == 'expense_sheet'
      # expense_sheet용 - 법인카드 명세서 전용
      <<~PROMPT
        법인카드 명세서를 분석하여 거래 내역을 추출하세요.
        
        ## 응답 형식
        {
          "type": "corporate_card",
          "data": {
            "transactions": [
              {
                "date": "MM/DD",
                "merchant": "가맹점명",
                "amount": 원금,
                "fee": 수수료,
                "total": 원금+수수료
              }
            ],
            "total_amount": 전체원금합계,
            "total_fee": 전체수수료합계,
            "grand_total": 전체원금+전체수수료
          }
        }
        
        ## 규칙
        - 모든 거래 내역을 빠짐없이 추출
        - 금액은 숫자만 (쉼표, 원 제외)
        - 각 거래의 total = amount + fee 계산필수
        - 날짜는 MM/DD 형식
        
        JSON:
      PROMPT
    elsif attachment_type == 'expense_item'
      # expense_item용 - 일반 문서 (telecom, general, unknown)
      <<~PROMPT
        다음 문서를 분석하여 타입을 분류하고 JSON으로 응답하세요.
        
        ## 문서 타입 (3가지)
        1. telecom: 통신비 청구서 (SKT, KT, LG U+, 알뜰폰)
        2. general: 일반 영수증 (식당, 카페, 쇼핑, 교통)
        3. unknown: 분류 불가
        
        ## 타입별 JSON 형식
        
        ### telecom (통신비)
        {
          "type": "telecom",
          "data": {
            "total_amount": 청구금액,
            "service_charge": 통신요금,
            "additional_service_charge": 부가서비스,
            "device_installment": 단말기할부,
            "other_charges": 기타요금,
            "discount_amount": 할인금액,
            "billing_period": "MM/DD~MM/DD"
          }
        }
        
        ### general (일반영수증)
        {
          "type": "general",
          "data": {
            "store_name": "상호",
            "location": "주소",
            "total_amount": 총액,
            "date": "MM/DD",
            "items": [{"name": "품목", "amount": 금액}]
          }
        }
        
        ### unknown (분류불가)
        {
          "type": "unknown",
          "data": {
            "summary_text": "요약(100자이내)"
          }
        }
        
        ## 규칙
        - 금액은 숫자만 (쉼표,원 제외)
        - 날짜는 MM/DD 형식
        - 유효한 JSON만 응답
        
        JSON:
      PROMPT
    else
      # 기본 - 모든 타입 가능 (기존 unified_prompt와 동일)
      build_unified_prompt('')
    end
  end
  
  # 경비 검증 전용 API 호출 메서드 (Gemini 2.5 Pro 사용)
  # Pro 모델이 필요할 때 사용 - 더 정확한 검증이 필요한 경우
  # 사용법: analyze_for_validation 메서드에서 call_api 대신 call_api_for_validation 호출
  def call_api_for_validation(prompt, temperature: 0.1, max_tokens: 8000)
    retries = 0
    start_time = Time.current
    
    begin
      # 경비 검증은 Gemini 2.5 Pro 모델 사용
      model = 'gemini-2.5-pro'
      @logger.info "Gemini API 호출 (검증용) - 사용 모델: #{model}"
      
      # 직접 HTTP 요청
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{@api_key}")
      
      generation_config = {
        temperature: temperature,
        maxOutputTokens: max_tokens,
        topP: 0.95,
        topK: 40
      }
      
      # Gemini 2.5 Pro는 thinking 설정 지원
      generation_config[:thinkingConfig] = {
        # 검증 작업은 복잡하므로 충분한 thinking 토큰 할당
        thinkingBudget: 2048
      }
      
      body = {
        contents: [
          {
            role: 'user',
            parts: [{ text: prompt }]
          }
        ],
        generationConfig: generation_config
      }
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60  # 검증은 더 긴 시간이 필요할 수 있음
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json
      
      response = http.request(request)
      
      @logger.info "API 응답 코드: #{response.code}"
      
      unless response.code == '200'
        @logger.error "API 오류 응답: #{response.body}"
        raise ApiCallError, "API 응답 오류: #{response.code} - #{response.body}"
      end
      
      result = JSON.parse(response.body)
      
      # parts 배열 체크
      content = result.dig('candidates', 0, 'content')
      if content && content['parts'].nil?
        @logger.warn "parts 배열이 없음. content: #{content.inspect}"
      end
      
      full_response = result.dig('candidates', 0, 'content', 'parts', 0, 'text') || ""
      
      # 빈 응답 체크
      if full_response.empty?
        @logger.warn "API가 빈 응답 반환. 전체 결과: #{result.inspect}"
        finish_reason = result.dig('candidates', 0, 'finishReason')
        if finish_reason == 'MAX_TOKENS'
          @logger.error "MAX_TOKENS 에러: 응답이 토큰 제한을 초과했습니다"
        end
      end
      
      # 토큰 사용량 추출
      token_metadata = result.dig('usageMetadata')
      token_info = {
        prompt_tokens: token_metadata&.dig('promptTokenCount'),
        completion_tokens: token_metadata&.dig('candidatesTokenCount'),
        total_tokens: token_metadata&.dig('totalTokenCount'),
        cached_tokens: token_metadata&.dig('cachedContentTokenCount')
      }
      
      token_count = token_info[:total_tokens] || full_response.split.size
      
      # 응답 로그
      @logger.info "API 응답 (검증): #{full_response[0..200]}"
      @logger.info "토큰 사용량 - 프롬프트: #{token_info[:prompt_tokens]}, 응답: #{token_info[:completion_tokens]}, 총: #{token_info[:total_tokens]}"
      
      # 성공 메트릭 기록
      duration = ((Time.current - start_time) * 1000).round
      metrics_service.track_api_call(
        success: true, 
        duration: duration, 
        tokens_used: token_count
      )
      
      # 응답과 토큰 정보를 함께 반환
      { response: full_response, token_usage: token_info }
    rescue => e
      retries += 1
      if retries <= GeminiConfig::MAX_RETRIES
        logger.warn "Gemini API 호출 재시도 #{retries}/#{GeminiConfig::MAX_RETRIES}: #{e.message}"
        sleep(retries * 2)
        retry
      else
        duration = ((Time.current - start_time) * 1000).round
        metrics_service.track_api_call(
          success: false, 
          duration: duration, 
          error: e
        )
        raise ApiCallError, "Gemini API 호출 실패: #{e.message}"
      end
    end
  end
  
  def call_api(prompt, temperature: GeminiConfig::TEMPERATURE, max_tokens: 1000)
    retries = 0
    start_time = Time.current
    
    begin
      # API 호출 전 모델 확인 로그
      @logger.info "Gemini API 호출 - 사용 모델: #{GeminiConfig::MODEL}"
      
      # 직접 HTTP 요청
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{GeminiConfig::MODEL}:generateContent?key=#{@api_key}")
      
      generation_config = {
        temperature: temperature,
        maxOutputTokens: max_tokens,
        topP: 0.95,
        topK: 40
      }
      
      # Gemini 2.5 모델에서만 thinking 설정 추가
      if GeminiConfig::MODEL.include?('2.5')
        generation_config[:thinkingConfig] = {
          # thinking 토큰 제한 (0으로 설정하면 비활성화, -1은 동적 할당)
          # 영수증 분석은 간단한 작업이므로 적은 thinking 토큰만 사용
          thinkingBudget: 512
        }
      end
      
      body = {
        contents: [
          {
            role: 'user',
            parts: [{ text: prompt }]
          }
        ],
        generationConfig: generation_config
      }
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json
      
      response = http.request(request)
      
      @logger.info "API 응답 코드: #{response.code}"
      
      unless response.code == '200'
        @logger.error "API 오류 응답: #{response.body}"
        raise ApiCallError, "API 응답 오류: #{response.code} - #{response.body}"
      end
      
      result = JSON.parse(response.body)
      
      # parts 배열 체크
      content = result.dig('candidates', 0, 'content')
      if content && content['parts'].nil?
        @logger.warn "parts 배열이 없음. content: #{content.inspect}"
      end
      
      full_response = result.dig('candidates', 0, 'content', 'parts', 0, 'text') || ""
      
      # 빈 응답 체크
      if full_response.empty?
        @logger.warn "API가 빈 응답 반환. 전체 결과: #{result.inspect}"
        # finishReason이 MAX_TOKENS인 경우 더 작은 토큰으로 재시도 필요
        finish_reason = result.dig('candidates', 0, 'finishReason')
        if finish_reason == 'MAX_TOKENS'
          @logger.error "MAX_TOKENS 에러: 응답이 토큰 제한을 초과했습니다"
        end
      end
      
      # 토큰 사용량 추출
      token_metadata = result.dig('usageMetadata')
      token_info = {
        prompt_tokens: token_metadata&.dig('promptTokenCount'),
        completion_tokens: token_metadata&.dig('candidatesTokenCount'),
        total_tokens: token_metadata&.dig('totalTokenCount'),
        cached_tokens: token_metadata&.dig('cachedContentTokenCount')
      }
      
      token_count = token_info[:total_tokens] || full_response.split.size
      
      # 응답 로그
      @logger.info "API 응답 전체: #{full_response[0..200]}"
      @logger.info "토큰 사용량 - 프롬프트: #{token_info[:prompt_tokens]}, 응답: #{token_info[:completion_tokens]}, 총: #{token_info[:total_tokens]}"
      
      # 성공 메트릭 기록
      duration = ((Time.current - start_time) * 1000).round # 밀리초
      metrics_service.track_api_call(
        success: true, 
        duration: duration, 
        tokens_used: token_count
      )
      
      # 응답과 토큰 정보를 함께 반환
      { response: full_response, token_usage: token_info }
    rescue => e
      retries += 1
      if retries <= GeminiConfig::MAX_RETRIES
        logger.warn "Gemini API 호출 재시도 #{retries}/#{GeminiConfig::MAX_RETRIES}: #{e.message}"
        sleep(retries * 2) # 지수 백오프
        retry
      else
        # 실패 메트릭 기록
        duration = ((Time.current - start_time) * 1000).round
        metrics_service.track_api_call(
          success: false, 
          duration: duration, 
          error: e
        )
        raise ApiCallError, "Gemini API 호출 실패: #{e.message}"
      end
    end
  end
  
  # JSON 응답 규칙을 프롬프트 앞에 추가
  def build_final_prompt_with_json_rules(db_prompt)
    json_rules = <<~JSON_RULES
      [중요 규칙]
      반드시 유효한 JSON 형식으로만 응답하세요.
      마크다운 코드블록(```json```) 없이 순수 JSON만 반환하세요.
      응답은 파싱 가능한 유효한 JSON이어야 합니다.
      
    JSON_RULES
    
    json_rules + db_prompt
  end
  
  # Multimodal API 호출 (파일 직접 전송)
  def call_multimodal_api(base64_data, mime_type, prompt, temperature: 0.1, max_tokens: 2000)
    retries = 0
    start_time = Time.current
    
    begin
      @logger.info "Gemini Multimodal API 호출 - 모델: #{GeminiConfig::MODEL}"
      
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{GeminiConfig::MODEL}:generateContent?key=#{@api_key}")
      
      generation_config = {
        temperature: temperature,
        maxOutputTokens: max_tokens,
        topP: 0.95,
        topK: 40
      }
      
      # Gemini 2.5 모델에서만 thinking 설정 추가
      if GeminiConfig::MODEL.include?('2.5')
        generation_config[:thinkingConfig] = {
          thinkingBudget: 512
        }
      end
      
      # Multimodal 요청 구성
      body = {
        contents: [
          {
            role: 'user',
            parts: [
              {
                inline_data: {
                  mime_type: mime_type,
                  data: base64_data
                }
              },
              {
                text: prompt
              }
            ]
          }
        ],
        generationConfig: generation_config
      }
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60 # 파일 처리는 더 오래 걸릴 수 있음
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json
      
      response = http.request(request)
      
      @logger.info "Multimodal API 응답 코드: #{response.code}"
      
      unless response.code == '200'
        @logger.error "Multimodal API 오류 응답: #{response.body}"
        raise ApiCallError, "API 오류 (#{response.code}): #{response.body}"
      end
      
      result = JSON.parse(response.body)
      
      # 응답 텍스트 추출
      full_response = ''
      
      # 일반 텍스트 응답 추출
      if result['candidates']&.first&.dig('content', 'parts')
        result['candidates'].first['content']['parts'].each do |part|
          if part['text']
            full_response += part['text']
          end
        end
      end
      
      if full_response.empty?
        @logger.warn "Multimodal API가 빈 응답 반환"
      end
      
      @logger.info "Multimodal API 응답: #{full_response[0..200]}"
      
      # 성공 메트릭 기록
      duration = ((Time.current - start_time) * 1000).round
      metrics_service.track_api_call(
        success: true,
        duration: duration,
        tokens_used: result.dig('usageMetadata', 'totalTokenCount') || 0
      )
      
      full_response
    rescue => e
      retries += 1
      if retries <= GeminiConfig::MAX_RETRIES
        logger.warn "Multimodal API 호출 재시도 #{retries}/#{GeminiConfig::MAX_RETRIES}: #{e.message}"
        sleep(retries * 2)
        retry
      else
        duration = ((Time.current - start_time) * 1000).round
        metrics_service.track_api_call(
          success: false,
          duration: duration,
          error: e
        )
        raise ApiCallError, "Multimodal API 호출 실패: #{e.message}"
      end
    end
  end
  
  def build_unified_prompt(text)
    <<~PROMPT
      다음 문서를 분석하여 정확히 하나의 타입으로 분류하고 JSON으로 응답하세요.
      
      ## 문서 타입 (4가지)
      1. corporate_card: 법인카드 명세서
      2. telecom: 통신비 청구서 (SKT, KT, LG U+, 알뜰폰)
      3. general: 일반 영수증 (식당, 카페, 쇼핑, 교통)
      4. unknown: 분류 불가
      
      ## 타입별 JSON 형식
      
      ### corporate_card (법인카드 명세서)
      {
        "type": "corporate_card",
        "data": {
          "transactions": [
            {
              "date": "MM/DD",
              "merchant": "가맹점명",
              "amount": 원금,
              "fee": 수수료,
              "total": 원금+수수료
            }
          ],
          "total_amount": 전체원금합계,
          "total_fee": 전체수수료합계,
          "grand_total": 전체원금+전체수수료
        }
      }
      
      ### telecom (통신비)
      {
        "type": "telecom",
        "data": {
          "total_amount": 청구금액,
          "service_charge": 통신요금,
          "additional_service_charge": 부가서비스,
          "device_installment": 단말기할부,
          "other_charges": 기타요금,
          "discount_amount": 할인금액,
          "billing_period": "MM/DD~MM/DD"
        }
      }
      
      ### general (일반영수증)
      {
        "type": "general",
        "data": {
          "store_name": "상호",
          "location": "주소",
          "total_amount": 총액,
          "date": "MM/DD",
          "items": [{"name": "품목", "amount": 금액}]
        }
      }
      
      ### unknown (분류불가)
      {
        "type": "unknown",
        "data": {
          "summary_text": "요약(100자이내)"
        }
      }
      
      ## 규칙
      - 금액은 숫자만 (쉼표,원 제외)
      - 날짜는 MM/DD 형식
      - corporate_card는 각 거래의 total = amount + fee 계산필수
      - 유효한 JSON만 응답
      
      분석할 문서:
      #{text[0..4000]}
      
      JSON:
    PROMPT
  end
  
  
  def parse_unified_response(response)
    begin
      # JSON 부분만 추출
      json_match = response.match(/\{.*\}/m)
      unless json_match
        logger.warn "JSON 형식을 찾을 수 없음: #{response[0..200]}"
        return { receipt_type: 'unknown', summary: { summary_text: response } }
      end
      
      json_data = JSON.parse(json_match[0])
      
      receipt_type = json_data['type'] || 'unknown'
      data = json_data['data'] || {}
      
      # 금액 필드를 숫자로 변환
      if data.is_a?(Hash)
        data.each do |key, value|
          if key.include?('amount') || key.include?('charge') || key.include?('installment')
            data[key] = parse_amount(value)
          elsif key == 'items' && value.is_a?(Array)
            value.each do |item|
              item['amount'] = parse_amount(item['amount']) if item['amount']
            end
          end
        end
      end
      
      {
        receipt_type: receipt_type,
        summary: data.with_indifferent_access
      }
    rescue JSON::ParserError => e
      logger.warn "JSON 파싱 실패: #{e.message}"
      { receipt_type: 'unknown', summary: { summary_text: response } }
    end
  end
  
  
  def parse_amount(value)
    return nil if value.nil?
    return value if value.is_a?(Numeric)
    
    # 문자열에서 숫자만 추출
    cleaned = value.to_s.gsub(/[^0-9.]/, '')
    cleaned.present? ? cleaned.to_f : nil
  end
  
  # JSON 응답 규칙을 포함한 최종 프롬프트 생성
  def build_final_prompt_with_json_rules(base_prompt)
    <<~PROMPT
      ## JSON 응답 필수 규칙
      1. 반드시 유효한 JSON 형식으로만 응답
      2. 마크다운 코드 블록(```) 사용 금지
      3. 설명이나 주석 없이 순수 JSON만 반환
      4. 시작은 { 끝은 } 로 끝나야 함
      
      #{base_prompt}
    PROMPT
  end

  # AttachmentRequirement 기반 동적 프롬프트 생성
  def build_dynamic_prompt(text, prompt_template, expected_fields, receipt_type)
    # 예상 필드 정보를 JSON 스키마로 변환
    field_schema = build_field_schema(expected_fields) if expected_fields.present?
    
    <<~PROMPT
      #{prompt_template}
      
      #{'예상 출력 형식:' if field_schema.present?}
      #{field_schema if field_schema.present?}
      
      중요 규칙:
      - 반드시 유효한 JSON 형식으로만 응답
      - 마크다운 코드 블록(```) 사용 금지, 순수 JSON만 응답
      - 금액은 숫자값만 (원, 쉼표 제외)
      - 날짜는 YYYY-MM-DD 형식
      - 찾을 수 없는 정보는 null로 표시
      
      분석할 텍스트:
      #{text[0..4000]}
      
      JSON 응답:
    PROMPT
  end
  
  # 예상 필드를 JSON 스키마로 변환
  def build_field_schema(expected_fields)
    return nil if expected_fields.blank?
    
    # transactions가 array인 경우 특별 처리
    if expected_fields["transactions"] == "array"
      return <<~SCHEMA
        {
          "transactions": [
            {
              "usage_date": "YYYY-MM-DD",
              "merchant_name": "가맹점명",
              "usage_amount": 숫자값,
              "fee": 숫자값,
              "total_amount": 숫자값
            }
          ]
        }
      SCHEMA
    end
    
    schema = "{\n"
    schema += "  \"type\": \"#{expected_fields['type'] || 'unknown'}\",\n" if expected_fields['type']
    schema += "  \"data\": {\n"
    
    expected_fields.each do |field, type|
      next if field == 'type'
      example_value = case type
                     when 'number' then '숫자값'
                     when 'date' then '"YYYY-MM-DD"'
                     when 'array' then '[]'
                     else '"문자열"'
                     end
      schema += "    \"#{field}\": #{example_value},\n"
    end
    
    schema = schema.chomp(",\n") + "\n"
    schema += "  }\n"
    schema += "}"
    
    schema
  end
  
  # 검증 프롬프트 빌드
  def build_validation_prompt(validation_data)
    # validation_data는 이미 구조화된 해시이므로 문자열로 변환
    <<~PROMPT
      #{validation_data[:system_prompt]}
      
      ## 검증 규칙
      #{validation_data[:validation_rules]}
      
      ## 첨부파일 분석 결과
      #{validation_data[:expense_sheet_data].to_json}
      
      ## 경비 항목 리스트
      #{validation_data[:expense_items].to_json}
      
      ## 요청사항
      #{validation_data[:request]}
    PROMPT
  end
  
  # 검증 응답 파싱
  def parse_validation_response(response)
    begin
      logger.info "검증 응답 원본 길이: #{response.length}자"
      
      # 응답이 잘렸는지 확인
      if response.length < 100
        logger.warn "응답이 너무 짧음: #{response}"
        return {
          'validation_summary' => 'AI 응답이 너무 짧습니다. 다시 시도해주세요.',
          'all_valid' => false,
          'validation_details' => [],
          'issues_found' => ['응답 길이 부족 - 재시도 필요'],
          'recommendations' => []
        }
      end
      
      # 마크다운 코드 블록 제거 (```json 또는 ``` 제거)
      cleaned_response = response.gsub(/```[^\n]*\n?/, '').gsub(/```/, '').strip
      
      # 추가 텍스트 제거 (## 검증 결과 등)
      cleaned_response = cleaned_response.gsub(/^##.*$/m, '').strip
      
      # 일반적인 JSON 오류 수정
      # 1. 후행 쉼표 제거
      cleaned_response = cleaned_response.gsub(/,(\s*[}\]])/, '\1')
      # 2. 이스케이프되지 않은 따옴표 처리
      cleaned_response = cleaned_response.gsub(/([^\\])"([^",:}\]]*)"([^,:}\]])/, '\1\"\2\"\3')
      
      # 불완전한 JSON 처리 - 열린 배열/객체 닫기
      open_brackets = cleaned_response.count('[') - cleaned_response.count(']')
      open_braces = cleaned_response.count('{') - cleaned_response.count('}')
      
      if open_brackets > 0
        cleaned_response += ']' * open_brackets
        logger.warn "불완전한 JSON - 배열 닫기 추가: #{open_brackets}개"
      end
      
      if open_braces > 0
        cleaned_response += '}' * open_braces
        logger.warn "불완전한 JSON - 객체 닫기 추가: #{open_braces}개"
      end
      
      # JSON 부분 추출 (더 유연한 정규식)
      json_match = cleaned_response.match(/\{[\s\S]*\}/m)
      unless json_match
        logger.warn "검증 응답에서 JSON을 찾을 수 없음"
        logger.warn "정리된 응답 (처음 500자): #{cleaned_response[0..500]}"
        return {
          'validation_summary' => 'AI 응답 형식이 올바르지 않습니다. JSON 형식이 아닙니다.',
          'all_valid' => false,
          'validation_details' => [],
          'issues_found' => ['JSON 형식 오류 - 재검증 버튼을 다시 클릭해주세요'],
          'recommendations' => []
        }
      end
      
      json_str = json_match[0]
      logger.info "추출된 JSON 길이: #{json_str.length}자"
      
      # JSON 파싱 시도
      json_data = JSON.parse(json_str)
      
      # 필수 필드 확인 및 기본값 설정
      result = {
        'validation_summary' => json_data['validation_summary'] || '검증 완료',
        'all_valid' => json_data['all_valid'] || false,
        'validation_details' => json_data['validation_details'] || [],
        'issues_found' => json_data['issues_found'] || [],
        'recommendations' => json_data['recommendations'] || []
      }
      
      # suggested_order가 있으면 추가
      if json_data['suggested_order']
        result['suggested_order'] = json_data['suggested_order']
        logger.info "suggested_order 발견: #{json_data['suggested_order'].inspect}"
      end
      
      # validation_details가 비어있는지 확인
      if result['validation_details'].empty?
        logger.warn "validation_details가 비어있음 - 개별 항목 검증 결과 누락"
        result['validation_summary'] = "#{result['validation_summary']} (주의: 개별 항목 검증 결과가 누락되었습니다)"
        result['issues_found'] << "개별 항목 검증 결과가 생성되지 않았습니다. 재검증을 시도해주세요."
      end
      
      logger.info "파싱 성공 - all_valid: #{result['all_valid']}, details count: #{result['validation_details'].length}"
      result
      
    rescue JSON::ParserError => e
      logger.error "검증 응답 JSON 파싱 실패: #{e.message}"
      
      # 부분적으로라도 파싱 시도
      begin
        # validation_summary와 all_valid만이라도 추출
        summary_match = cleaned_response.match(/"validation_summary"\s*:\s*"([^"]+)"/)
        all_valid_match = cleaned_response.match(/"all_valid"\s*:\s*(true|false)/)
        
        # validation_details 배열 부분 추출 시도
        details_match = cleaned_response.match(/"validation_details"\s*:\s*\[([^\]]*)/m)
        details = []
        
        if details_match
          # 각 항목을 개별적으로 파싱 시도
          detail_items = details_match[1].scan(/\{[^}]*\}/)
          detail_items.each do |item|
            begin
              # 불완전한 항목 완성
              if !item.include?('"message"')
                item = item.sub(/\}$/, ',"message":"검증 중""}')
              end
              detail = JSON.parse(item)
              details << detail
            rescue
              # 개별 항목 파싱 실패 시 무시
            end
          end
        end
        
        result = {
          'validation_summary' => summary_match ? summary_match[1] : 'AI 검증 중 일부 데이터 파싱 오류가 발생했습니다.',
          'all_valid' => all_valid_match ? all_valid_match[1] == 'true' : false,
          'validation_details' => details,
          'issues_found' => ["검증 항목별 상세 결과가 불완전합니다. 재검증 버튼을 다시 클릭해주세요."],
          'recommendations' => []
        }
        
        logger.warn "부분 파싱 성공 - details count: #{details.length}"
        result
        
      rescue => inner_e
        logger.error "부분 파싱도 실패: #{inner_e.message}"
        
        {
          'validation_summary' => 'AI 응답 처리 중 기술적 오류가 발생했습니다.',
          'all_valid' => false,
          'validation_details' => [],
          'issues_found' => ["응답 형식 처리 실패. 재검증 버튼을 다시 클릭해주세요."],
          'recommendations' => ["문제가 계속되면 시스템 관리자에게 문의하세요."]
        }
      end
    end
  end
  
  # 동적 응답 파싱
  def parse_dynamic_response(response, expected_fields = nil, receipt_type = nil)
    begin
      logger.info "원본 응답 (처음 100자): #{response[0..100]}"
      
      # 마크다운 코드 블록 제거 (모든 백틱 제거)
      cleaned_response = response.gsub(/```[^\n]*\n?/, '').gsub(/```/, '').strip
      
      logger.info "정리된 응답 (처음 100자): #{cleaned_response[0..100]}"
      
      # JSON 부분 추출 (객체 또는 배열)
      json_match = cleaned_response.match(/(\{.*\}|\[.*\])/m)
      unless json_match
        logger.warn "JSON 형식을 찾을 수 없음: #{response[0..200]}"
        return { receipt_type: receipt_type, summary: { summary_text: response } }
      end
      
      logger.info "JSON 매치 성공, 파싱 시도..."
      json_data = JSON.parse(json_match[0])
      
      # 배열 형태 응답 처리 (법인카드 명세서의 경우)
      if json_data.is_a?(Array)
        # 배열을 transactions 키로 감싸기
        json_data = { 'transactions' => json_data }
      end
      
      # type이 있으면 사용, 없으면 데이터 구조로 타입 추론
      actual_type = json_data['type'] || receipt_type
      
      # 타입이 없고 transactions 배열이 있으면 corporate_card로 판단
      if !actual_type && (json_data['transactions'] || json_data['data']&.dig('transactions'))
        actual_type = 'corporate_card'
      end
      
      data = json_data['data'] || json_data # data 필드가 없으면 전체를 data로 사용
      
      # 금액 필드를 숫자로 변환 (transactions 내부의 amount도 처리)
      if data.is_a?(Hash)
        data.each do |key, value|
          if key == 'transactions' && value.is_a?(Array)
            value.each do |item|
              item['amount'] = parse_amount(item['amount']) if item['amount']
              item['fee'] = parse_amount(item['fee']) if item['fee']
              item['total'] = parse_amount(item['total']) if item['total']
            end
          elsif expected_fields && expected_fields[key] == 'number'
            data[key] = parse_amount(value)
          elsif key.include?('amount') || key.include?('charge') || key.include?('installment')
            data[key] = parse_amount(value)
          elsif key == 'items' && value.is_a?(Array)
            value.each do |item|
              item['amount'] = parse_amount(item['amount']) if item['amount']
            end
          end
        end
      end
      
      # type과 data를 함께 반환
      {
        'type' => actual_type,
        'data' => data.with_indifferent_access
      }
    rescue JSON::ParserError => e
      logger.warn "JSON 파싱 실패: #{e.message}"
      logger.warn "파싱 시도한 텍스트: #{json_match ? json_match[0][0..200] : 'no match'}"
      { 'type' => receipt_type || 'unknown', 'data' => { summary_text: response } }
    end
  end
end