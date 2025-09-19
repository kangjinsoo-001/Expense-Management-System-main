class ExpenseValidationService
  def initialize(expense_sheet, current_user = nil)
    @expense_sheet = expense_sheet
    @current_user = current_user
    @gemini_service = GeminiService.new
  end
  
  # 토큰 사용량을 한국 원화로 계산
  def calculate_cost_in_krw(token_usage)
    return nil unless token_usage
    
    # Gemini 2.5 Flash 가격 (2025년 기준)
    input_price_per_million = 0.30  # USD
    output_price_per_million = 2.50 # USD
    usd_to_krw = 1400 # 환율
    
    input_tokens = token_usage[:prompt_tokens] || token_usage['prompt_tokens'] || 0
    output_tokens = token_usage[:completion_tokens] || token_usage['completion_tokens'] || 0
    
    input_cost_usd = input_tokens / 1_000_000.0 * input_price_per_million
    output_cost_usd = output_tokens / 1_000_000.0 * output_price_per_million
    total_cost_usd = input_cost_usd + output_cost_usd
    
    (total_cost_usd * usd_to_krw).round(1)
  end
  
  # 기존 한번에 검증하는 메서드
  def validate_with_ai(sheet_attachments, expense_items)
    validate_with_ai_all_at_once(sheet_attachments, expense_items)
  end
  
  # 단일 단계만 실행하는 메서드 (컨텍스트 유지)
  def validate_single_step_with_context(sheet_attachments, expense_items, step_number, previous_context = {})
    # 이전 단계에서 실패했는지 확인 (중단 조건)
    if step_number > 1
      # 1단계부터 이전 단계까지 검사
      (1...step_number).each do |prev_step|
        prev_result = previous_context["step_#{prev_step}"]
        if prev_result && prev_result[:status] == 'failed'
          Rails.logger.info "단계 #{prev_step}에서 검증 실패. 단계 #{step_number} 건너뜀"
          
          # 모든 항목을 "미검증" 상태로 반환
          items_data = extract_expense_items_data(expense_items)
          return {
            step: step_number,
            name: get_step_name(step_number),
            status: 'skipped',
            validation_details: items_data.map { |item|
              {
                'item_id' => item[:id],
                'item_name' => item[:expense_code],
                'status' => '미검증',
                'message' => "이전 단계 검증 실패로 인해 건너뜀"
              }
            },
            issues_found: [],
            recommendations: ["이전 단계의 문제를 먼저 해결하세요"],
            token_usage: { total_tokens: 0, prompt_tokens: 0, completion_tokens: 0 },
            debug_info: { skipped: true, reason: "Step #{prev_step} failed" }
          }
        end
      end
    end
    
    # 1. 첨부파일 분석 결과 추출
    attachment_data = extract_attachment_data(sheet_attachments)
    
    # 2. 경비 항목 데이터 추출
    items_data = extract_expense_items_data(expense_items)
    
    # 3. 검증 규칙 가져오기
    validation_rules = get_validation_rules
    
    # 4. 해당 단계의 규칙만 선택 (3단계 검증)
    step_info = case step_number
    when 1
      { rule: validation_rules[0], name: '첨부파일 검증', step: 1 }
    when 2
      { rule: validation_rules[1], name: '통신비 검증', step: 2 }
    when 3
      # 존재여부, 순서, 금액 통합 검증
      { rule: validation_rules[2], name: '항목 순서/금액 검증', step: 3 }
    when 4
      # 영수증 첨부 확인
      { rule: { rule_type: 'receipt_attachment_check', prompt_text: '법인카드 명세서에 없는 항목의 영수증 첨부 확인', severity: 'error' }, name: '영수증 첨부 확인', step: 4 }
    end
    
    return { error: '유효하지 않은 단계' } unless step_info[:rule]
    
    Rails.logger.info "검증 단계 #{step_number} 시작: #{step_info[:name]}"
    
    # 5. 단일 규칙으로 검증 실행 (최적화된 데이터 전송)
    step_result = case step_number
    when 1
      # 첨부파일 검증
      validate_step_1_attachment(attachment_data, items_data, step_info[:rule])
    when 2
      # 통신비 위치 검증 및 자동 조정
      validate_step_2_telecom(items_data, step_info[:rule])
    when 3
      # 존재여부, 순서, 금액 통합 검증 + 명세서 순서대로 재정렬
      result = validate_step_3_combined(attachment_data, items_data, step_info[:rule])
      
      # 재정렬 실행
      if result[:suggested_order] && result[:suggested_order]['reorder_needed']
        reorder_items_by_card_statement(expense_items, result[:suggested_order])
        result[:debug_info] ||= {}
        result[:debug_info][:items_reordered] = true
        
        # reorder_details 또는 suggested_order 키 확인
        reorder_data = result[:suggested_order]['reorder_details'] || result[:suggested_order]['suggested_order']
        result[:debug_info][:reorder_count] = reorder_data ? reorder_data.size : 0
        
        # items_needing_receipts 정보 추가
        if result[:suggested_order]['items_needing_receipts']
          result[:debug_info][:items_needing_receipts] = result[:suggested_order]['items_needing_receipts']
          result[:debug_info][:receipt_needed_count] = result[:suggested_order]['items_needing_receipts'].size
        end
      end
      
      result
    when 4
      # 영수증 첨부 확인 (3단계에서 식별된 항목)
      validate_step_4_receipt_check(@expense_sheet.expense_items.not_drafts, previous_context)
    else
      { error: '유효하지 않은 단계' }
    end
    
    # 6. 경비 항목 업데이트 (현재 단계 결과만 반영)
    update_items_from_step_result(expense_items, step_result)
    
    # 7. 검증 실패 여부 판단
    # 완전 통과가 아니면 모두 실패로 처리
    has_any_issues = step_result[:validation_details]&.any? { |d| 
      # '완료' 상태가 아니거나 메시지에 문제 관련 키워드가 있으면 실패
      d['status'] != '완료' || 
      d['message']&.include?('경고') || 
      d['message']&.include?('주의') ||
      d['message']&.include?('확인 필요') ||
      d['message']&.include?('영수증')
    }
    
    # 8. 단계 결과 반환
    # 문제가 하나라도 있으면 failed, 완전 통과만 success
    final_status = has_any_issues ? 'failed' : 'success'
    
    # 비용 계산
    cost_krw = calculate_cost_in_krw(step_result[:token_usage])
    
    result = {
      step: step_number,
      name: step_info[:name],
      status: final_status,
      validation_details: step_result[:validation_details],
      issues_found: step_result[:issues_found],
      recommendations: step_result[:recommendations],
      token_usage: step_result[:token_usage],
      cost_krw: cost_krw,
      debug_info: step_result[:debug_info]
    }
    
    # 3단계인 경우 suggested_order 정보 추가
    if step_number == 3 && step_result[:suggested_order]
      result[:suggested_order] = step_result[:suggested_order]
      Rails.logger.info "최종 반환값에 suggested_order 추가: #{step_result[:suggested_order].present?}"
    end
    
    # 4단계인 경우 영수증 검증 결과 추가
    if step_number == 4 && step_result[:receipt_check]
      result[:receipt_check] = step_result[:receipt_check]
    end
    
    result
  end
  
  # 단계 이름 가져오기 헬퍼 메서드
  def get_step_name(step_number)
    case step_number
    when 1 then '통신비 검증'
    when 2 then '존재 여부 검증'
    when 3 then '순서 검증'
    when 4 then '금액 검증'
    else '알 수 없는 단계'
    end
  end
  
  # 모든 단계 결과를 종합하는 메서드
  def compile_all_steps_result(context)
    Rails.logger.info "=== compile_all_steps_result 시작 ==="
    
    # 항목별로 모든 단계의 결과를 종합
    item_results = {}
    
    # 각 단계 결과 수집
    (1..4).each do |step|
      step_result = context["step_#{step}"]
      Rails.logger.info "단계 #{step} 결과: #{step_result.present? ? '있음' : '없음'}"
      next unless step_result
      
      Rails.logger.info "단계 #{step} validation_details 개수: #{step_result[:validation_details]&.size}"
      
      # 각 항목별로 결과 저장
      step_result[:validation_details]&.each do |detail|
        item_id = detail['item_id'].to_i
        item_results[item_id] ||= {
          'item_id' => item_id,
          'item_name' => detail['item_name'],
          'statuses' => [],
          'messages' => []
        }
        
        item_results[item_id]['statuses'] << detail['status']
        item_results[item_id]['messages'] << "#{step}단계: #{detail['message']}" if detail['message'].present?
        
        Rails.logger.info "  item_id=#{item_id}, 단계#{step} status=#{detail['status']}"
      end
    end
    
    # 각 항목의 최종 상태 결정
    final_details = item_results.map do |item_id, results|
      # 하나라도 '확인 필요'가 있으면 '확인 필요'
      # 모두 '완료'면 '완료'
      # 그 외는 '미검증'
      final_status = if results['statuses'].include?('확인 필요')
                      '확인 필요'
                    elsif results['statuses'].all? { |s| s == '완료' }
                      '완료'
                    else
                      '미검증'
                    end
      
      final_message = results['messages'].join('; ')
      final_message = '모든 검증 통과' if final_message.blank? && final_status == '완료'
      
      Rails.logger.info "최종 상태 결정: item_id=#{item_id}, status=#{final_status}"
      
      {
        'item_id' => item_id,
        'item_name' => results['item_name'],
        'status' => final_status,
        'message' => final_message
      }
    end
    
    # issues_found와 recommendations 수집
    accumulated_issues = []
    accumulated_recommendations = []
    total_tokens = { total_tokens: 0, prompt_tokens: 0, completion_tokens: 0 }
    
    (1..4).each do |step|
      step_result = context["step_#{step}"]
      next unless step_result
      
      accumulated_issues.concat(step_result[:issues_found] || [])
      accumulated_recommendations.concat(step_result[:recommendations] || [])
      
      # 토큰 사용량 누적
      if step_result[:token_usage]
        total_tokens[:total_tokens] += step_result[:token_usage][:total_tokens] || 0
        total_tokens[:prompt_tokens] += step_result[:token_usage][:prompt_tokens] || 0
        total_tokens[:completion_tokens] += step_result[:token_usage][:completion_tokens] || 0
      end
    end
    
    # 4단계 영수증 검증 결과 확인
    step_4_data = context["step_4"] || {}
    receipt_check = step_4_data[:receipt_check] || {}
    items_missing_receipts = receipt_check['items_missing_receipts'] || []
    
    # 전체 유효성 확인 (영수증 누락도 체크)
    has_warnings = final_details.any? { |d| d['status'] == '확인 필요' }
    has_missing_receipts = items_missing_receipts.any?
    all_valid = !has_warnings && !has_missing_receipts
    
    warning_count = final_details.count { |d| d['status'] == '확인 필요' }
    
    Rails.logger.info "=== 최종 결과 ==="
    Rails.logger.info "총 validation_details 개수: #{final_details.size}"
    Rails.logger.info "확인 필요 항목 수: #{warning_count}"
    Rails.logger.info "영수증 누락 항목 수: #{items_missing_receipts.size}"
    Rails.logger.info "모든 항목 유효: #{all_valid}"
    
    # 비용 계산
    cost_krw = calculate_cost_in_krw(total_tokens)
    
    # 검증 요약 메시지 생성 (토큰 정보는 별도로 처리)
    validation_summary = if all_valid
      "모든 경비 항목이 검증을 통과했습니다."
    elsif has_missing_receipts && has_warnings
      "#{warning_count}개 항목에서 확인이 필요하고, #{items_missing_receipts.size}개 항목에 영수증 첨부가 필요합니다."
    elsif has_missing_receipts
      "#{items_missing_receipts.size}개 항목에 영수증 첨부가 필요합니다."
    else
      "#{warning_count}개 항목에서 확인이 필요합니다."
    end
    
    final_result = {
      validation_summary: validation_summary,
      all_valid: all_valid,
      validation_details: final_details,
      issues_found: accumulated_issues.uniq,
      recommendations: accumulated_recommendations.uniq,
      token_usage: total_tokens,
      cost_krw: cost_krw,
      validated_at: Time.current
    }
    
    # 검증 이력 저장 - 컨트롤러에서 처리하므로 여기서는 제거
    # save_validation_history는 컨트롤러에서 직접 호출
    
    # ExpenseSheet 업데이트
    @expense_sheet.update!(
      validation_result: final_result,
      validation_status: final_result[:all_valid] ? 'validated' : 'warning',
      validated_at: Time.current
    )
    
    final_result
  end
  
  # 단계별로 검증하는 새로운 메서드
  def validate_with_ai_stepwise(sheet_attachments, expense_items, &progress_block)
    # 1. 첨부파일 분석 결과 추출
    attachment_data = extract_attachment_data(sheet_attachments)
    
    # 2. 경비 항목 데이터 추출
    items_data = extract_expense_items_data(expense_items)
    
    # 3. 검증 규칙 가져오기
    validation_rules = get_validation_rules
    
    # 4. 검증 단계 정의
    validation_steps = [
      { rule: validation_rules[0], name: '통신비 검증', step: 1 },
      { rule: validation_rules[1], name: '순서 검증', step: 2 },
      { rule: validation_rules[2], name: '존재 여부 검증', step: 3 },
      { rule: validation_rules[3], name: '금액 검증', step: 4 }
    ].compact
    
    # 5. 누적 결과 초기화
    accumulated_results = {
      validation_details: [],
      issues_found: [],
      recommendations: [],
      token_usage: { total_tokens: 0, prompt_tokens: 0, completion_tokens: 0 },
      step_results: []  # 각 단계별 결과 저장
    }
    
    # 6. 각 단계별로 검증 실행
    validation_steps.each do |step_info|
      begin
        # 진행 상황 브로드캐스트
        broadcast_progress(step_info[:step], step_info[:name], 'processing')
        progress_block.call(step_info[:step], step_info[:name], 'processing') if progress_block
        
        # 단일 규칙으로 검증 실행
        step_result = validate_single_rule(
          attachment_data, 
          items_data, 
          step_info[:rule],
          step_info[:step],
          step_info[:name]  # 단계 이름도 전달
        )
        
        # 상태 결정 (완전 통과가 아니면 모두 failed)
        step_status = if step_result[:validation_details]&.any? { |d| 
            d['status'] != '완료' || 
            d['message']&.include?('경고') || 
            d['message']&.include?('주의') ||
            d['message']&.include?('확인 필요') ||
            d['message']&.include?('영수증')
          }
          'failed'
        else
          'success'
        end
        
        # 단계별 결과 저장 (디버깅용)
        accumulated_results[:step_results] << {
          step: step_info[:step],
          name: step_info[:name],
          status: step_status,
          debug_info: step_result[:debug_info],
          token_usage: step_result[:token_usage]
        }
        
        # 결과 누적
        merge_step_results(accumulated_results, step_result, expense_items)
        
        # 완료 상태 브로드캐스트
        broadcast_progress(step_info[:step], step_info[:name], step_status)
        progress_block.call(step_info[:step], step_info[:name], step_status) if progress_block
        
        # 실패 상태이면 나머지 단계 건너뛰기
        if step_status == 'failed'
          Rails.logger.info "단계 #{step_info[:step]}에서 문제 발견. 검증 중단."
          
          # 나머지 단계를 'skipped' 상태로 처리
          validation_steps[(validation_steps.index(step_info) + 1)..-1].each do |skipped_step|
            broadcast_progress(skipped_step[:step], skipped_step[:name], 'skipped')
            progress_block.call(skipped_step[:step], skipped_step[:name], 'skipped') if progress_block
            
            accumulated_results[:step_results] << {
              step: skipped_step[:step],
              name: skipped_step[:name],
              status: 'skipped',
              debug_info: { skipped: true, reason: "Step #{step_info[:step]} failed" }
            }
          end
          
          break  # 루프 중단
        end
        
      rescue => e
        Rails.logger.error "검증 단계 #{step_info[:step]} 실패: #{e.message}"
        broadcast_progress(step_info[:step], step_info[:name], 'error')
        progress_block.call(step_info[:step], step_info[:name], 'error') if progress_block
      end
    end
    
    # 7. 최종 결과 생성
    final_result = compile_final_result(accumulated_results, expense_items)
    
    # 8. 검증 이력 저장
    save_validation_history(final_result, attachment_data, items_data)
    
    # 9. ExpenseSheet 업데이트
    @expense_sheet.update!(
      validation_result: final_result,
      validation_status: final_result[:all_valid] ? 'validated' : 'warning',
      validated_at: Time.current
    )
    
    # 10. step_results 추가 (JavaScript 콘솔 로깅용)
    final_result[:step_results] = accumulated_results[:step_results]
    
    final_result
  end
  
  # 기존 모든 규칙을 한번에 검증하는 메서드
  def validate_with_ai_all_at_once(sheet_attachments, expense_items)
    # 1. 첨부파일 분석 결과 추출
    attachment_data = extract_attachment_data(sheet_attachments)
    
    # 2. 경비 항목 데이터 추출
    items_data = extract_expense_items_data(expense_items)
    
    # 3. 검증 규칙 가져오기
    validation_rules = get_validation_rules
    
    # 4. Gemini API 호출을 위한 프롬프트 생성
    prompt = build_validation_prompt(attachment_data, items_data, validation_rules)
    
    
    # 5. Gemini API 호출
    gemini_response = @gemini_service.analyze_for_validation(prompt)
    
    # 토큰 사용량 정보 추출 (있는 경우)
    token_usage = gemini_response.delete('token_usage') if gemini_response.is_a?(Hash)
    
    # 6. 응답 파싱 및 포맷팅
    validation_result = format_validation_response(gemini_response, expense_items)
    
    # 토큰 사용량 정보 추가
    validation_result[:token_usage] = token_usage if token_usage
    
    # 7. 검증 이력 저장
    save_validation_history(validation_result, attachment_data, items_data)
    
    # 8. ExpenseSheet의 최신 검증 결과 업데이트
    @expense_sheet.update!(
      validation_result: validation_result,
      validation_status: validation_result[:all_valid] ? 'validated' : 'warning',
      validated_at: Time.current
    )
    
    # 9. 이력 정보를 포함한 결과 반환 (디버깅용 프롬프트 포함)
    validation_result.merge(
      history_count: @expense_sheet.validation_histories.count,
      previous_validations: @expense_sheet.validation_histories.recent.limit(3).map do |history|
        {
          id: history.id,
          created_at: history.created_at,
          summary: history.validation_summary,
          all_valid: history.all_valid,
          warning_count: history.warning_count
        }
      end,
      # 디버깅용 프롬프트 정보 추가
      debug_prompt: prompt
    )
  rescue => e
    Rails.logger.error "ExpenseValidationService 오류: #{e.message}"
    raise e
  end
  
  private
  
  # 단계 결과로 경비 항목 업데이트
  def update_items_from_step_result(expense_items, step_result)
    # 각 단계에서는 업데이트하지 않음 (4단계 완료 시에만 업데이트)
    # 이 메서드는 비워둠 (호환성 유지)
    return
  end
  
  def extract_attachment_data(sheet_attachments)
    sheet_attachments.map do |attachment|
      {
        id: attachment.id,
        file_name: attachment.file_name,
        analysis_result: attachment.analysis_result,
        status: attachment.status
      }
    end
  end
  
  def extract_expense_items_data(expense_items)
    expense_items.map do |item|
      {
        id: item.id,
        expense_date: item.expense_date,
        expense_code: item.expense_code.name,
        expense_code_code: item.expense_code.code,
        description: item.description,
        amount: item.amount,
        position: item.position,
        validation_status: item.validation_status
      }
    end
  end
  
  def get_validation_rules
    # AttachmentRequirement에서 경비 시트용 검증 규칙 가져오기
    requirement = AttachmentRequirement.for_expense_sheets
                                      .where(name: '법인카드 명세서')
                                      .first
    
    if requirement&.validation_rules&.any?
      rules = requirement.validation_rules.active.ordered.map do |rule|
        {
          rule_type: rule.rule_type,
          prompt_text: rule.prompt_text,
          severity: rule.severity
        }
      end
      
      # 순서 재배열: 1.통신비, 2.존재여부, 3.순서, 4.금액
      reorder_validation_rules(rules)
    else
      # 기본 검증 규칙 제공 (이미 올바른 순서)
      default_validation_rules
    end
  end
  
  # 검증 규칙 순서 재배열
  def reorder_validation_rules(rules)
    ordered = []
    
    # 1. 통신비 검증
    telecom = rules.find { |r| r[:rule_type] == 'telecom_check' }
    ordered << telecom if telecom
    
    # 2. 존재 여부 검증 (순서 변경)
    existence = rules.find { |r| r[:rule_type] == 'existence_check' }
    ordered << existence if existence
    
    # 3. 순서 검증 (순서 변경)
    order = rules.find { |r| r[:rule_type] == 'order_match' }
    ordered << order if order
    
    # 4. 금액 검증
    amount = rules.find { |r| r[:rule_type] == 'amount_match' }
    ordered << amount if amount
    
    # 나머지 규칙들 (있을 경우)
    rules.each do |rule|
      unless ordered.include?(rule)
        ordered << rule
      end
    end
    
    ordered
  end
  
  def default_validation_rules
    # 5단계 검증: 1.첨부파일, 2.통신비, 3.존재여부, 4.순서, 5.금액
    [
      {
        rule_type: 'attachment_check',
        prompt_text: '경비 시트에 통신비(PHON) 이외의 항목이 하나라도 있으면 첨부파일(법인카드 명세서)이 반드시 필요. 통신비만 있는 경우 첨부파일 없어도 통과.',
        severity: 'error'
      },
      {
        rule_type: 'telecom_check',
        prompt_text: '날짜가 일치하는지는 검증할 필요 없음. 통신비(PHON)가 있는 경우 반드시 최상단(position 1)에 위치해야 함. 통신비가 없는 것은 문제 없음.',
        severity: 'warning'
      },
      {
        rule_type: 'existence_check',
        prompt_text: '날짜가 일치하는지는 검증할 필요 없음. 통신비를 제외한 항목들에 대해: 법인카드 명세서에 없는데 경비 시트에 있다면 영수증 필수 "경고". 법인카드 명세서에 있는데 경비 시트에 없으면 "확인 필요"로 "주의".',
        severity: 'warning'
      },
      {
        rule_type: 'order_match',
        prompt_text: '날짜가 일치하는지는 검증할 필요 없음. 입력 순서만 검증하면 됨. 통신비는 최상단 위치 1번에 배치. 법인카드 명세서에 없는 경비 시트 항목은 하단에 배치되어야 함. 법인카드 명세서에 있는 경비 시트 항목은 법인카드 명세서의 순서와 경비 시트 입력 순서가 일치해야 함. (단, 통신비로 인해 1줄씩 밀린 순서는 허용)',
        severity: 'warning'
      },
      {
        rule_type: 'amount_match',
        prompt_text: '날짜가 일치하는지는 검증할 필요 없음. 통신비를 제외한 항목들에 대해: 경비 시트의 입력 항목별 "경비 시트 금액 > 법인카드 명세서 금액"보다 크면 "경고".',
        severity: 'error'
      }
    ]
  end
  
  def build_validation_prompt(attachment_data, items_data, validation_rules)
    # 각 경비 항목 ID를 명시적으로 문자열로 만들어 프롬프트 생성
    items_for_prompt = items_data.map.with_index do |item, index|
      "순서 #{index + 1}: ID #{item[:id]} - #{item[:expense_code]} - #{item[:description]} (#{item[:amount]}원)"
    end.join("\n")
    
    {
      system_prompt: "Corporate card statement and expense item validation expert. IMPORTANT Validation Rules Priority: The validation rules are listed in priority order from top to bottom. Rules listed first have higher priority. When validation rules conflict, apply the rule that appears first in the list.",
      
      validation_rules: validation_rules.map.with_index { |rule, index| 
        "#{index + 1}. #{rule[:rule_type]}: #{rule[:prompt_text]}"
      }.join("\n"),
      
      expense_sheet_data: attachment_data,
      
      expense_items: items_data,
      
      request: "다음 형식의 순수 JSON만 반환하세요. 마크다운이나 설명 텍스트 절대 금지:
{\"validation_summary\":\"요약\",\"all_valid\":false,\"validation_details\":[{\"item_id\":48,\"item_name\":\"차량유지비\",\"status\":\"확인 필요\",\"message\":\"설명\"},{\"item_id\":50,\"item_name\":\"초과근무 식대\",\"status\":\"확인 필요\",\"message\":\"설명\"},{\"item_id\":51,\"item_name\":\"도서인쇄비\",\"status\":\"확인 필요\",\"message\":\"설명\"},{\"item_id\":52,\"item_name\":\"잡비\",\"status\":\"확인 필요\",\"message\":\"설명\"}],\"issues_found\":[],\"recommendations\":[]}

검증할 경비 항목:
#{items_for_prompt}

필수 요구사항:
1. validation_details 배열은 반드시 위에 나열된 모든 경비 항목(총 #{items_data.length}개)에 대한 검증 결과를 포함해야 합니다.
2. 검증 통과한 항목도 반드시 포함하세요. status='완료', message='검증 통과' 또는 적절한 설명을 작성하세요.
3. 문제가 있는 항목만 나열하지 말고, 모든 항목(#{items_data.length}개)을 빠짐없이 작성하세요.
4. 각 항목마다 item_id, item_name, status, message를 반드시 작성하세요.
5. status는 '완료'(검증 통과), '확인 필요'(문제 있음), '미검증'(검증 불가) 중 하나입니다."
    }
  end
  
  def format_validation_response(gemini_response, expense_items)
    # Gemini 응답이 JSON 형식인지 확인
    if gemini_response.is_a?(Hash)
      validation_data = gemini_response
    else
      # 문자열 응답을 JSON으로 파싱 시도
      begin
        validation_data = JSON.parse(gemini_response)
      rescue JSON::ParserError
        # JSON 파싱 실패 시 기본 구조 생성
        validation_data = {
          'validation_summary' => gemini_response.to_s[0..200],
          'all_valid' => false,
          'validation_details' => []
        }
      end
    end
    
    # 경비 항목 validation_status 업데이트
    if validation_data['validation_details'].present?
      validation_data['validation_details'].each do |detail|
        item = expense_items.find { |i| i.id == detail['item_id'].to_i }
        if item
          # 상태 매핑
          new_status = case detail['status']
                      when '완료'
                        'validated'
                      when '확인 필요'
                        'warning'
                      when '미검증'
                        'pending'
                      else
                        'pending'
                      end
          
          # DB 업데이트
          item.update_columns(
            validation_status: new_status,
            validation_message: detail['message'],
            validated_at: Time.current
          )
        end
      end
    end
    
    # 응답 반환
    {
      validation_summary: validation_data['validation_summary'],
      all_valid: validation_data['all_valid'] || false,
      validation_details: validation_data['validation_details'] || [],
      issues_found: validation_data['issues_found'] || [],
      recommendations: validation_data['recommendations'] || [],
      validated_at: Time.current
    }
  end
  
  def save_validation_history(result, attachments, items)
    # 사용자가 제공되지 않으면 시스템 사용자 사용
    user = @current_user || User.find_by(email: 'system@example.com') || User.first
    
    @expense_sheet.validation_histories.create!(
      validated_by: user,
      validation_summary: result[:validation_summary],
      all_valid: result[:all_valid],
      validation_details: result[:validation_details],
      issues_found: result[:issues_found],
      recommendations: result[:recommendations],
      attachment_data: attachments,
      expense_items_data: items
    )
  rescue => e
    Rails.logger.error "검증 이력 저장 실패: #{e.message}"
    # 이력 저장 실패해도 검증은 계속 진행
  end
  
  # 1단계: 첨부파일 검증 (새로 추가)
  def validate_step_1_attachment(attachment_data, items_data, rule)
    # 통신비가 아닌 항목이 있는지 확인
    non_telecom_items = items_data.select { |item| 
      item[:expense_code] != '통신비' && item[:expense_code] != 'PHON'
    }
    
    has_attachments = attachment_data.present? && attachment_data.any?
    has_non_telecom = non_telecom_items.any?
    
    Rails.logger.info "1단계 첨부파일 검증: 첨부파일 #{has_attachments ? '있음' : '없음'}, 통신비 외 항목 #{has_non_telecom ? '있음' : '없음'}"
    
    validation_details = []
    issues_found = []
    
    if has_non_telecom && !has_attachments
      # 통신비 외 항목이 있는데 첨부파일이 없음 - 경고만 표시하고 진행
      validation_details = items_data.map do |item|
        {
          'item_id' => item[:id],
          'item_name' => item[:expense_code],
          'status' => '확인 필요',
          'message' => '첨부파일 없음 - 법인카드 명세서 첨부를 권장합니다'
        }
      end
      issues_found << "통신비 외 항목이 있으나 첨부파일이 없습니다 (검증은 계속 진행)"
      
      return {
        step: 1,
        name: '첨부파일 검증',
        status: 'warning',  # failed 대신 warning으로 변경
        validation_details: validation_details,
        issues_found: issues_found,
        recommendations: ['법인카드 명세서 첨부를 권장합니다 (필수 아님)'],
        token_usage: { total_tokens: 0, prompt_tokens: 0, completion_tokens: 0 },
        debug_info: { 
          has_attachments: has_attachments,
          has_non_telecom: has_non_telecom,
          non_telecom_count: non_telecom_items.count,
          attachment_optional: true  # 첨부파일이 옵셔널임을 표시
        }
      }
    else
      # 검증 통과
      validation_details = items_data.map do |item|
        {
          'item_id' => item[:id],
          'item_name' => item[:expense_code],
          'status' => '완료',
          'message' => has_non_telecom ? '첨부파일 확인 완료' : '통신비만 있어 첨부파일 불필요'
        }
      end
      
      return {
        step: 1,
        name: '첨부파일 검증',
        status: 'success',
        validation_details: validation_details,
        issues_found: [],
        recommendations: [],
        token_usage: { total_tokens: 0, prompt_tokens: 0, completion_tokens: 0 },
        debug_info: { 
          has_attachments: has_attachments,
          has_non_telecom: has_non_telecom,
          non_telecom_count: non_telecom_items.count
        }
      }
    end
  end
  
  # 2단계 최적화: 통신비 위치 검증 및 자동 수정
  def validate_step_2_telecom(items_data, rule)
    # 통신비 항목만 필터링
    telecom_items = items_data.select { |item| item[:expense_code] == '통신비' || item[:expense_code] == 'PHON' }
    
    Rails.logger.info "2단계 검증: 통신비 항목 #{telecom_items.size}건 발견"
    
    # 항목들을 위치 순서대로 정렬
    sorted_items = items_data.sort_by { |item| item[:position] || 999 }
    first_position_item = sorted_items.first
    
    # position이 가장 작은 값 찾기 (보통 1이지만 다를 수 있음)
    min_position = sorted_items.first[:position] if sorted_items.any?
    
    Rails.logger.info "첫 번째 위치(position=#{min_position}) 항목: #{first_position_item[:expense_code]}" if first_position_item
    Rails.logger.info "통신비 항목 위치: #{telecom_items.map { |t| "ID:#{t[:id]}, Position:#{t[:position]}" }.join(', ')}" if telecom_items.any?
    
    # 통신비가 있고 첫 번째 위치가 아닌 경우 자동으로 위치 변경
    position_changed = false
    if telecom_items.any? && telecom_items.none? { |t| t[:position] == min_position }
      Rails.logger.info "통신비 위치 자동 수정 시작"
      
      # 실제 ExpenseItem 모델을 사용하여 position 업데이트
      telecom_item_id = telecom_items.first[:id]
      telecom_expense_item = ExpenseItem.find(telecom_item_id)
      
      # 모든 아이템의 position을 재배열
      all_expense_items = ExpenseItem.where(expense_sheet_id: telecom_expense_item.expense_sheet_id)
                                     .where(is_draft: false)
                                     .order(:position)
      
      # 통신비를 position 1로, 나머지는 순차적으로 재배열
      new_position = 1
      telecom_expense_item.update!(position: new_position)
      
      all_expense_items.where.not(id: telecom_item_id).each do |item|
        new_position += 1
        item.update!(position: new_position)
      end
      
      position_changed = true
      Rails.logger.info "통신비(ID: #{telecom_item_id})를 position 1로 이동 완료"
      
      # items_data도 업데이트 (메모리상에서)
      telecom_items.each { |t| t[:position] = 1 }
      other_items = items_data.reject { |item| item[:expense_code] == '통신비' || item[:expense_code] == 'PHON' }
      other_items.sort_by! { |item| item[:position] || 999 }
      other_items.each_with_index { |item, idx| item[:position] = idx + 2 }
    end
    
    # 검증 결과 직접 생성 (Gemini 호출 최소화)
    validation_details = items_data.map do |item|
      if item[:expense_code] == '통신비' || item[:expense_code] == 'PHON'
        # 통신비 항목
        if position_changed
          # 위치가 자동 수정됨
          {
            'item_id' => item[:id],
            'item_name' => item[:expense_code],
            'status' => '완료',
            'message' => '통신비를 최상단으로 자동 이동했습니다'
          }
        elsif item[:position] == min_position
          # 이미 첫 번째 위치에 있음 - 올바름
          {
            'item_id' => item[:id],
            'item_name' => item[:expense_code],
            'status' => '완료',
            'message' => '통신비가 올바른 위치(최상단)에 있습니다'
          }
        else
          # 첫 번째 위치가 아님 - 문제 (이 경우는 발생하지 않아야 함)
          {
            'item_id' => item[:id],
            'item_name' => item[:expense_code],
            'status' => '확인 필요',
            'message' => '통신비는 최상단 위치에 있어야 합니다'
          }
        end
      else
        # 통신비가 아닌 항목
        if position_changed
          {
            'item_id' => item[:id],
            'item_name' => item[:expense_code],
            'status' => '완료',
            'message' => '통신비 이동으로 순서가 재정렬되었습니다'
          }
        else
          {
            'item_id' => item[:id],
            'item_name' => item[:expense_code],
            'status' => '완료',
            'message' => '2단계 통신비 검증 통과'
          }
        end
      end
    end
    
    # 통신비가 없는 경우 또는 첫 번째 위치에 없는 경우 경고 추가
    issues_found = []
    if telecom_items.empty?
      issues_found << "통신비 항목이 없습니다"
    elsif first_position_item && first_position_item[:expense_code] != '통신비' && first_position_item[:expense_code] != 'PHON'
      issues_found << "통신비가 최상단 위치에 없습니다"
    end
    
    {
      validation_details: validation_details,
      issues_found: issues_found,
      recommendations: [],
      token_usage: {
        'total_tokens' => 0,
        'prompt_tokens' => 0, 
        'completion_tokens' => 0
      }
    }
  end
  
  # 3단계 통합: 존재 여부, 순서, 금액 검증 + 명세서 순서대로 재정렬
  def validate_step_3_combined(attachment_data, items_data, rule)
    # 법인카드 명세서의 거래 내역 추출 (순서 포함)
    card_transactions = []
    attachment_data.each do |attachment|
      if attachment[:analysis_result]
        # transactions가 여러 위치에 있을 수 있으므로 모두 확인
        transactions = nil
        
        # 1. 직접 transactions 키 확인
        if attachment[:analysis_result]['transactions']
          transactions = attachment[:analysis_result]['transactions']
        # 2. summary_data.data.transactions 확인
        elsif attachment[:analysis_result]['summary_data'] && 
              attachment[:analysis_result]['summary_data']['data'] &&
              attachment[:analysis_result]['summary_data']['data']['transactions']
          transactions = attachment[:analysis_result]['summary_data']['data']['transactions']
        end
        
        if transactions
          transactions.each_with_index do |transaction, index|
            card_transactions << {
              order: index + 1,
              merchant: transaction['merchant'],
              date: transaction['date'],
              amount: transaction['total'] || transaction['amount']
            }
          end
        end
      end
    end
    
    Rails.logger.info "3단계 통합 검증: 카드 거래 #{card_transactions.size}건, 경비 항목 #{items_data.size}건"
    
    # 통신비를 제외한 항목들만 검증 대상 (position 2부터)
    non_telecom_items = items_data.reject { |item| 
      item[:expense_code] == '통신비' || item[:expense_code] == 'PHON'
    }
    
    # Gemini에 보낼 프롬프트 구성
    # 더 간결하지만 명확한 프롬프트
    items_list = items_data.map { |item|
      {
        id: item[:id],
        amount: item[:amount],
        is_telecom: item[:expense_code] == '통신비',
        description: item[:description],
        expense_code: item[:expense_code]
      }
    }
    
    # 카드 거래 내역 로깅
    Rails.logger.info "==== 3단계 카드 거래 내역 ===="
    card_transactions.each do |tx|
      Rails.logger.info "카드 거래: #{tx[:merchant]} - #{tx[:amount]}원 (#{tx[:date]})"
    end
    Rails.logger.info "==== 3단계 경비 항목 ===="
    items_list.each do |item|
      Rails.logger.info "경비 항목 ID #{item[:id]}: #{item[:expense_code]} - #{item[:amount]}원 - #{item[:description]}"
    end
    
    # Gemini에 전달할 프롬프트 구성 - 더 명확한 지시사항
    prompt = {
      system_prompt: "경비 검증 전문가. JSON 형식으로만 응답하세요.",
      validation_rules: "1. 통신비는 항상 position 1에 위치\n2. 카드 매칭 항목은 카드 명세서 순서대로 position 2부터\n3. 카드 명세서에 없는 항목은 맨 뒤로\n4. 카드 명세서에 없는 항목 식별",
      expense_sheet_data: card_transactions,
      expense_items: items_list,
      request: <<~REQUEST
        다음 두 목록을 비교 분석하세요:
        
        [카드 거래 내역]
        #{card_transactions.map { |t| "- #{t[:date]}: #{t[:amount]}원 - #{t[:description]}" }.join("\n")}
        
        [경비 항목]
        #{items_list.map { |i| "- ID #{i[:id]}: #{i[:amount]}원 - #{i[:expense_code]} - #{i[:description]}" }.join("\n")}
        
        작업:
        1. 각 경비 항목이 카드 거래와 매칭되는지 금액 기준으로 확인
        2. **정렬 순서 (매우 중요)**:
           - 통신비(expense_code: 'EC002'): position 1 고정
           - 카드 거래와 매칭되는 항목: position 2부터 카드 거래 순서대로
           - 카드 거래와 매칭되지 않는 항목: 맨 뒤 position부터 (예: 총 10개면 8,9,10 위치)
        3. **중요**: 카드 거래 금액과 일치하지 않는 모든 경비 항목은 items_needing_receipts에 포함
        
        예시:
        - 총 10개 항목이 있고, 3개가 카드 매칭 안 되면:
        - 통신비: position 1
        - 카드 매칭 항목 6개: position 2~7
        - 영수증 필요 항목 3개: position 8~10
        
        JSON 응답 형식 (반드시 이 형식만 사용):
        {
          "suggested_order": {
            "reorder_needed": true,
            "reorder_details": [
              {"item_id": 숫자, "pos": 숫자}
            ],
            "items_needing_receipts": [
              {"item_id": 숫자, "description": "설명", "reason": "카드 명세서에 없음", "amount": 금액}
            ]
          }
        }
        
        특별 지시:
        - 통신비(EC002)는 카드 매칭 여부와 관계없이 영수증 불필요
        - 그 외 모든 항목은 카드 거래 금액과 정확히 일치하지 않으면 items_needing_receipts에 포함
        - 영수증 필요 항목은 반드시 맨 뒤 position으로 배치
        - 예: 13521원 경비 항목이 있고 카드 거래에 13521원이 없다면 반드시 items_needing_receipts에 포함하고 맨 뒤로
      REQUEST
    }
    
    # 브라우저 콘솔 출력용 디버그 정보 준비
    Rails.logger.info "="*80
    Rails.logger.info "[3단계 Gemini API 호출]"
    Rails.logger.info "요청 데이터:"
    Rails.logger.info "- 카드 거래: #{card_transactions.size}건"
    Rails.logger.info "- 경비 항목: #{items_list.size}건"
    Rails.logger.info "- 프롬프트: #{prompt[:request]}"
    Rails.logger.info "="*80
    
    # Gemini API 호출
    @gemini_service ||= GeminiService.new
    response = @gemini_service.analyze_for_validation_flash(prompt)
    
    # Gemini 응답 로깅
    Rails.logger.info "="*80
    Rails.logger.info "[3단계 Gemini 응답]"
    Rails.logger.info "원본 응답: #{response.inspect}"
    Rails.logger.info "="*80
    
    # 토큰 정보 로깅
    if response && response['token_usage']
      Rails.logger.info "3단계 토큰 사용량: #{response['token_usage'].inspect}"
    end
    
    # 응답 파싱
    Rails.logger.info "parse_step_response 호출 전 - response 타입: #{response.class.name}"
    result = parse_step_response(response, items_data)
    Rails.logger.info "parse_step_response 호출 후 - result 타입: #{result.class.name}, 값: #{result.inspect[0..100]}"
    
    Rails.logger.info "파싱된 결과 타입: #{result.class.name}"
    
    # result가 Hash가 아닌 경우 기본 구조 생성
    unless result.is_a?(Hash)
      Rails.logger.error "parse_step_response가 잘못된 타입 반환: #{result.inspect}"
      result = {
        validation_details: items_data.map { |item| 
          { 
            'item_id' => item[:id], 
            'item_name' => item[:expense_code],
            'status' => '미검증', 
            'message' => '응답 파싱 실패'
          }
        },
        issues_found: [],
        recommendations: []
      }
    end
    
    # suggested_order 정보 추가 (response와 result 모두에서 찾기)
    if response && response['suggested_order']
      result[:suggested_order] = response['suggested_order']
      Rails.logger.info "response에서 suggested_order 발견: #{response['suggested_order'].inspect}"
    elsif result && result[:suggested_order]
      Rails.logger.info "result에 이미 suggested_order 있음: #{result[:suggested_order].inspect}"
    else
      Rails.logger.warn "suggested_order를 찾을 수 없음"
    end
    
    # 브라우저 콘솔 출력을 위한 디버그 정보 추가
    result[:debug_info] ||= {}
    result[:debug_info][:gemini_request] = {
      card_transactions: card_transactions,
      expense_items: prompt[:expense_items]
    }
    result[:debug_info][:gemini_response] = response
    
    # 토큰 사용량 정보 추가
    if response && response['token_usage']
      result[:token_usage] = response['token_usage']
      result[:debug_info][:token_usage] = response['token_usage']
      Rails.logger.info "[3단계] 토큰 사용량: #{response['token_usage'].inspect}"
    end
    
    result
  end
  
  # 법인카드 명세서 순서대로 항목 재정렬 및 영수증 플래그 설정
  def reorder_items_by_card_statement(expense_items, suggested_order)
    return unless suggested_order
    
    Rails.logger.info "재정렬 시작 - suggested_order 구조: #{suggested_order.keys.inspect}"
    
    # 재정렬이 필요한 경우 (reorder_details 또는 suggested_order 키 확인)
    reorder_data = suggested_order['reorder_details'] || suggested_order['suggested_order']
    
    if suggested_order['reorder_needed'] && reorder_data
      Rails.logger.info "법인카드 명세서 순서대로 재정렬 시작 (#{reorder_data.size}개 항목)"
      
      # 재정렬 전 현재 position 로깅
      Rails.logger.info "재정렬 전 position: #{expense_items.map { |ei| "#{ei.id}:#{ei.position}" }.join(', ')}"
      
      reorder_data.each do |detail|
        # ID 타입 변환 (문자열 -> 정수)
        item_id = detail['item_id'].to_i
        # pos 또는 suggested_position 둘 다 지원
        suggested_pos = (detail['pos'] || detail['suggested_position']).to_i
        
        item = expense_items.find { |ei| ei.id == item_id }
        if item && item.position != suggested_pos
          Rails.logger.info "항목 #{item.id}(#{item.description}): position #{item.position} → #{suggested_pos}"
          item.update!(position: suggested_pos)
        elsif item.nil?
          Rails.logger.warn "항목 ID #{item_id}를 찾을 수 없음"
        end
      end
      
      # 재정렬 후 현재 position 로깅
      expense_items.reload
      Rails.logger.info "재정렬 후 position: #{expense_items.map { |ei| "#{ei.id}:#{ei.position}" }.join(', ')}"
      
      # 추가 검증: 영수증 필요 항목이 맨 뒤에 있는지 확인
      if suggested_order['items_needing_receipts'] && suggested_order['items_needing_receipts'].any?
        receipt_needed_ids = suggested_order['items_needing_receipts'].map { |r| r['item_id'].to_i }
        Rails.logger.info "영수증 필요 항목 ID: #{receipt_needed_ids.inspect}"
        
        # 전체 항목을 position 순으로 정렬
        sorted_items = expense_items.sort_by(&:position)
        total_count = sorted_items.size
        receipt_needed_count = receipt_needed_ids.size
        
        # 영수증 필요 항목들의 현재 position 확인
        receipt_items_positions = sorted_items.select { |item| receipt_needed_ids.include?(item.id) }.map(&:position)
        expected_start_position = total_count - receipt_needed_count + 1
        
        Rails.logger.info "영수증 필요 항목 현재 position: #{receipt_items_positions.inspect}"
        Rails.logger.info "영수증 필요 항목 예상 시작 position: #{expected_start_position}"
        
        # 영수증 필요 항목이 맨 뒤에 없으면 재조정
        if receipt_items_positions.min && receipt_items_positions.min < expected_start_position
          Rails.logger.info "영수증 필요 항목 위치 재조정 필요"
          
          # 1. 통신비는 position 1 유지
          # 2. 카드 매칭 항목들을 position 2부터 순서대로
          # 3. 영수증 필요 항목들을 맨 뒤로
          
          card_matched_items = sorted_items.reject { |item| 
            receipt_needed_ids.include?(item.id) || 
            item.expense_code.code == 'EC002'  # 통신비 제외
          }
          
          receipt_needed_items = sorted_items.select { |item| receipt_needed_ids.include?(item.id) }
          
          # position 재할당
          current_position = 2  # 통신비가 1번이므로 2부터 시작
          
          # 카드 매칭 항목들 position 설정
          card_matched_items.each do |item|
            if item.position != current_position
              Rails.logger.info "카드 매칭 항목 #{item.id} 위치 조정: #{item.position} → #{current_position}"
              item.update!(position: current_position)
            end
            current_position += 1
          end
          
          # 영수증 필요 항목들을 맨 뒤로
          receipt_needed_items.each do |item|
            if item.position != current_position
              Rails.logger.info "영수증 필요 항목 #{item.id} 위치 조정: #{item.position} → #{current_position}"
              item.update!(position: current_position)
            end
            current_position += 1
          end
          
          expense_items.reload
          Rails.logger.info "위치 재조정 후 position: #{expense_items.map { |ei| "#{ei.id}:#{ei.position}" }.join(', ')}"
        end
      end
    else
      Rails.logger.info "재정렬 불필요 또는 데이터 없음"
    end
    
    # 영수증이 필요한 항목 플래그 설정
    if suggested_order['items_needing_receipts'] && suggested_order['items_needing_receipts'].any?
      Rails.logger.info "영수증 필요 항목 플래그 설정 시작 (#{suggested_order['items_needing_receipts'].size}개)"
      
      suggested_order['items_needing_receipts'].each do |receipt_item|
        item_id = receipt_item['item_id'].to_i
        item = expense_items.find { |ei| ei.id == item_id }
        
        if item
          # validation_message에 영수증 필요 메모 추가
          message = item.validation_message || ""
          message += " [영수증 필요]" unless message.include?("[영수증 필요]")
          item.update!(
            validation_message: message.strip,
            validation_status: 'warning'  # 경고 상태로 설정
          )
          Rails.logger.info "항목 #{item.id}(#{item.description})에 영수증 필요 플래그 설정"
        else
          Rails.logger.warn "영수증 필요 항목 ID #{item_id}를 찾을 수 없음"
        end
      end
    end
    
    summary = suggested_order['reorder_summary'] || "재정렬 완료"
    Rails.logger.info "재정렬 및 플래그 설정 완료: #{summary}"
  end
  
  # 4단계: 법인카드 명세서에 없는 항목의 영수증 첨부 확인
  def validate_step_4_receipt_check(expense_items, previous_context)
    Rails.logger.info "4단계 영수증 첨부 확인 시작"
    
    # 3단계에서 식별된 영수증 필요 항목 가져오기
    step_3_data = previous_context['step_3'] || {}
    items_needing_receipts = []
    
    # 여러 위치에서 영수증 필요 항목 찾기
    if step_3_data[:suggested_order] && step_3_data[:suggested_order]['items_needing_receipts']
      items_needing_receipts = step_3_data[:suggested_order]['items_needing_receipts']
      Rails.logger.info "suggested_order에서 영수증 필요 항목 발견: #{items_needing_receipts.inspect}"
    elsif step_3_data[:debug_info] && step_3_data[:debug_info][:items_needing_receipts]
      items_needing_receipts = step_3_data[:debug_info][:items_needing_receipts]
      Rails.logger.info "debug_info에서 영수증 필요 항목 발견: #{items_needing_receipts.inspect}"
    end
    
    # 3단계에서 카드 거래 정보도 가져오기 (fallback용)
    card_transactions = []
    if step_3_data[:debug_info] && step_3_data[:debug_info][:gemini_request]
      card_transactions = step_3_data[:debug_info][:gemini_request][:card_transactions] || []
      Rails.logger.info "카드 거래 내역: #{card_transactions.map { |t| t[:amount] }.inspect}"
    end
    
    Rails.logger.info "영수증 필요 항목: #{items_needing_receipts.size}개"
    
    validation_details = []
    issues_found = []
    items_missing_receipts = []
    
    # 모든 경비 항목에 대해 검증
    expense_items.each do |item|
      next if item.is_draft?
      
      # 통신비는 영수증 불필요
      if item.expense_code == 'EC002'
        validation_details << {
          'item_id' => item.id,
          'item_name' => "#{item.expense_code} - #{item.description}",
          'status' => '완료',
          'message' => '통신비는 영수증 불필요'
        }
        next
      end
      
      # 이 항목이 영수증이 필요한 항목인지 확인
      needs_receipt = items_needing_receipts.any? { |r| r['item_id'].to_i == item.id }
      
      # Fallback: items_needing_receipts가 비어있으면 카드 거래와 직접 비교
      if items_needing_receipts.empty? && card_transactions.any?
        # 카드 거래에 해당 금액이 있는지 확인
        card_match = card_transactions.any? { |t| t[:amount].to_i == item.amount.to_i }
        needs_receipt = !card_match
        Rails.logger.info "Fallback 로직 - 항목 #{item.id}(#{item.amount}원): 카드매칭=#{card_match}, 영수증필요=#{needs_receipt}"
      end
      
      if needs_receipt
        # 해당 항목에 첨부파일이 있는지 확인
        has_attachment = item.expense_attachments.any?
        
        if has_attachment
          validation_details << {
            'item_id' => item.id,
            'item_name' => "#{item.expense_code.name} - #{item.description}",
            'status' => '완료',
            'message' => '영수증 첨부 확인됨'
          }
          
          # warning 상태를 validated로 변경
          item.update!(validation_status: 'validated')
        else
          validation_details << {
            'item_id' => item.id,
            'item_name' => "#{item.expense_code.name} - #{item.description}",
            'status' => '확인 필요',
            'message' => '법인카드 명세서에 없는 항목 - 영수증 첨부 필요'
          }
          items_missing_receipts << {
            'item_id' => item.id,
            'description' => item.description,
            'amount' => item.amount
          }
          
          # 실패 상태로 설정
          item.update!(
            validation_status: 'failed',
            validation_message: '영수증 첨부 필수'
          )
        end
      else
        # 영수증이 필요하지 않은 항목
        validation_details << {
          'item_id' => item.id,
          'item_name' => "#{item.expense_code.name} - #{item.description}",
          'status' => '완료',
          'message' => '법인카드 명세서 확인됨'
        }
      end
    end
    
    # 영수증이 없는 항목이 있으면 issues에 추가 (더 구체적인 메시지)
    if items_missing_receipts.any?
      issues_found << "❌ #{items_missing_receipts.size}개 항목에 영수증 첨부가 필요합니다:"
      items_missing_receipts.each do |item|
        expense_item = expense_items.find { |ei| ei.id == item['item_id'] }
        if expense_item
          amount_formatted = item['amount'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
          issues_found << "• #{expense_item.expense_code.name} - #{item['description']} (#{amount_formatted}원)"
          issues_found << "  → 법인카드 명세서에 없는 개인 경비로 영수증 첨부 필수"
        end
      end
    end
    
    # 최종 상태 결정
    final_status = items_missing_receipts.any? ? 'failed' : 'success'
    
    result = {
      step: 4,
      name: '영수증 첨부 확인',
      status: final_status,
      validation_details: validation_details,
      issues_found: issues_found,
      recommendations: items_missing_receipts.any? ? ['법인카드 명세서에 없는 항목들에 대해 영수증을 첨부해주세요'] : [],
      token_usage: { total_tokens: 0, prompt_tokens: 0, completion_tokens: 0 },
      debug_info: {
        items_needing_receipts_count: items_needing_receipts.size,
        items_missing_receipts_count: items_missing_receipts.size
      },
      receipt_check: {
        items_needing_receipts: items_needing_receipts,
        items_missing_receipts: items_missing_receipts
      }
    }
    
    Rails.logger.info "4단계 검증 완료: #{final_status}, 영수증 필요 #{items_needing_receipts.size}개, 누락 #{items_missing_receipts.size}개"
    
    result
  end
  
  # [삭제됨] 이전 5단계 검증 메서드들은 더 이상 사용하지 않음
  # validate_step_3_existence, validate_step_4_order, validate_step_5_amounts는 
  # validate_step_3_combined로 통합됨
  
  # 3단계 최적화: 순서 검증 (순서 변경됨, 2단계 결과 활용)
  def validate_step_4_order(attachment_data, items_data, rule, previous_context)
    # 2단계에서 매칭된 항목 정보 활용
    step2_result = previous_context['step_2']
    
    # 매칭된 항목만 추출 (존재 확인된 항목)
    matched_items = if step2_result && step2_result[:validation_details]
      step2_result[:validation_details].select { |d| 
        d['status'] == '완료' && !d['message'].include?('영수증')
      }
    else
      []
    end
    
    if matched_items.empty?
      # 매칭된 항목이 없으면 모든 항목을 완료 처리
      return {
        validation_details: items_data.map { |item|
          {
            'item_id' => item[:id],
            'item_name' => item[:expense_code],
            'status' => '완료',
            'message' => '순서 검증 대상 아님'
          }
        },
        issues_found: []
      }
    end
    
    # 법인카드 명세서의 거래 순서 추출
    card_order = []
    attachment_data.each do |attachment|
      if attachment[:analysis_result] && attachment[:analysis_result]['transactions']
        attachment[:analysis_result]['transactions'].each_with_index do |transaction, i|
          card_order << {
            position: i + 1,
            merchant: transaction['merchant']
          }
        end
      end
    end
    
    Rails.logger.info "3단계 검증: 카드 거래 순서 #{card_order.size}건, 매칭된 항목 #{matched_items.size}건"
    
    expense_order = matched_items.map { |m|
      item = items_data.find { |i| i[:id] == m['item_id'].to_i }
      { 
        id: m['item_id'],
        position: item[:position],  # position은 항상 있어야 함
        description: item[:description]
      }
    }
    
    prompt = {
      system_prompt: "순서 검증 전문가",
      validation_rule: rule[:prompt_text],
      card_order: card_order,
      expense_order: expense_order,
      request: "매칭된 항목들의 순서가 일치하는지 확인. 통신비로 인한 1줄 밀림은 허용."
    }
    
    @gemini_service ||= GeminiService.new
    response = @gemini_service.analyze_for_validation_flash(prompt)
    
    # 토큰 정보 로깅
    if response && response['token_usage']
      Rails.logger.info "3단계 토큰 사용량: #{response['token_usage'].inspect}"
    else
      Rails.logger.warn "3단계: 토큰 정보 없음"
    end
    
    parse_step_response(response, items_data)
  end
  
  # 4단계 최적화: 금액 검증
  def validate_step_5_amounts(attachment_data, items_data, rule)
    # 법인카드 명세서의 거래 내역 추출
    card_transactions = []
    attachment_data.each do |attachment|
      if attachment[:analysis_result] && attachment[:analysis_result]['transactions']
        attachment[:analysis_result]['transactions'].each do |transaction|
          card_transactions << {
            merchant: transaction['merchant'],
            amount: transaction['total'] || transaction['amount']
          }
        end
      end
    end
    
    # 금액 비교에 필요한 데이터만 추출
    comparisons = items_data.map { |item|
      # 비슷한 이름의 카드 거래 찾기
      card_transaction = card_transactions.find { |t|
        merchant = t[:merchant].to_s.downcase
        description = item[:description].to_s.downcase
        merchant.include?(description) || description.include?(merchant)
      }
      
      {
        id: item[:id],
        description: item[:description],
        expense_amount: item[:amount],
        card_amount: card_transaction ? card_transaction[:amount] : nil
      }
    }.select { |c| c[:card_amount] } # 매칭된 것만
    
    Rails.logger.info "4단계 검증: 금액 비교 대상 #{comparisons.size}건"
    
    prompt = {
      system_prompt: "금액 검증 전문가",
      validation_rule: rule[:prompt_text],
      comparisons: comparisons,
      request: "경비 금액이 카드 금액보다 큰 경우만 '확인 필요'로 표시"
    }
    
    @gemini_service ||= GeminiService.new
    response = @gemini_service.analyze_for_validation_flash(prompt)
    
    # 토큰 정보 로깅
    if response && response['token_usage']
      Rails.logger.info "4단계 토큰 사용량: #{response['token_usage'].inspect}"
    else
      Rails.logger.warn "4단계: 토큰 정보 없음"
    end
    
    parse_step_response(response, items_data)
  end
  
  # 단일 검증 규칙 실행
  def validate_single_rule(attachment_data, items_data, rule, step_number, step_name = nil)
    # 단일 규칙만으로 프롬프트 생성
    prompt = build_single_rule_prompt(attachment_data, items_data, rule, step_number)
    
    # 디버깅 정보 저장
    debug_info = {
      step_number: step_number,
      step_name: step_name,
      rule_type: rule[:rule_type],
      prompt: prompt,
      items_count: items_data.length,
      attachments_count: attachment_data.length
    }
    
    # Gemini Flash 모델로 빠른 검증
    @gemini_service ||= GeminiService.new
    response = @gemini_service.analyze_for_validation_flash(prompt)
    
    # 토큰 사용량 추출
    token_usage = response.delete('token_usage') if response.is_a?(Hash)
    
    # 응답 파싱
    parsed = parse_step_response(response, items_data)
    parsed[:token_usage] = token_usage if token_usage
    # '완료' 상태가 아니면 모두 문제로 인식
    parsed[:has_issues] = parsed[:validation_details]&.any? { |d| 
      d['status'] != '완료' || 
      d['message']&.include?('경고') || 
      d['message']&.include?('주의') ||
      d['message']&.include?('확인 필요') ||
      d['message']&.include?('영수증')
    }
    parsed[:debug_info] = debug_info
    
    parsed
  end
  
  # 단일 규칙용 프롬프트 생성
  def build_single_rule_prompt(attachment_data, items_data, rule, step_number)
    items_for_prompt = items_data.map.with_index do |item, index|
      "#{index + 1}. ID #{item[:id]} - #{item[:expense_code]} - #{item[:description]} (#{item[:amount]}원)"
    end.join("\n")
    
    {
      system_prompt: "경비 검증 전문가. 단계 #{step_number} 검증만 수행.",
      
      validation_rule: "#{rule[:rule_type]}: #{rule[:prompt_text]}",
      
      expense_sheet_data: attachment_data,
      
      expense_items: items_data,
      
      request: "이 단계의 규칙만 적용하여 검증하세요. 간결한 JSON 응답:
{\"validation_details\":[{\"item_id\":1,\"status\":\"완료\",\"message\":\"검증 통과\"}],\"issues_found\":[]}

검증할 항목:
#{items_for_prompt}

각 항목에 대해 이 규칙만 적용하여 status와 message 작성.
status는 '완료'(문제없음) 또는 '확인 필요'(문제있음) 중 하나."
    }
  end
  
  # 단계별 응답 파싱
  def parse_step_response(response, items_data)
    Rails.logger.info "[parse_step_response] 시작 - response 타입: #{response.class.name}"
    begin
      # 응답 타입 확인 및 파싱
      if response.is_a?(String)
        # JSON 문자열에서 코드 블록 제거 (```json ... ``` 형태)
        cleaned_response = response.gsub(/```json\s*/, '').gsub(/```\s*$/, '').strip
        
        # JSON 파싱 시도
        begin
          data = JSON.parse(cleaned_response)
        rescue JSON::ParserError => e
          Rails.logger.error "JSON 파싱 실패: #{e.message}"
          Rails.logger.error "원본 응답: #{response[0..500]}"  # 처음 500자만 로그
          
          # 기본 구조 반환
          return {
            validation_details: items_data.map { |item| 
              { 
                'item_id' => item[:id], 
                'item_name' => item[:expense_code],
                'status' => '미검증', 
                'message' => 'AI 응답 파싱 실패'
              }
            },
            issues_found: [],
            recommendations: []
          }
        end
      else
        data = response
      end
      
      # AI가 반환한 validation_details (없을 수도 있음)
      ai_details = data['validation_details'] || []
      
      # validation_details가 없고 suggested_order만 있는 경우 처리
      if ai_details.empty? && data['suggested_order']
        # suggested_order의 reorder_details를 기반으로 validation_details 생성
        reorder_details = data['suggested_order']['reorder_details'] || []
        all_details = items_data.map do |item|
          # pos 또는 suggested_position 둘 다 확인
          reorder_item = reorder_details.find { |r| r['item_id'].to_i == item[:id] }
          suggested_pos = reorder_item ? (reorder_item['pos'] || reorder_item['suggested_position']) : nil
          {
            'item_id' => item[:id],
            'item_name' => item[:expense_code],
            'status' => '완료',
            'message' => suggested_pos ? "위치 #{suggested_pos}로 재정렬" : '검증 완료'
          }
        end
      else
        # 기존 로직: 모든 항목에 대한 검증 결과 확보
        all_details = items_data.map do |item|
          ai_result = ai_details.find { |d| d['item_id'].to_i == item[:id] }
          
          if ai_result
            {
              'item_id' => ai_result['item_id'],
              'item_name' => ai_result['item_name'] || item[:expense_code],
              'status' => ai_result['status'] || '완료',
              'message' => ai_result['message'] || '검증 완료'
            }
          else
            {
              'item_id' => item[:id],
              'item_name' => item[:expense_code],
              'status' => '완료',
              'message' => '검증 통과'
            }
          end
        end
      end
      
      Rails.logger.info "단계 응답 파싱 성공: AI 반환 #{ai_details.size}개, 전체 #{all_details.size}개 항목"
      
      # issues_found 필터링 (JSON 파싱 오류 메시지 제외)
      issues = (data['issues_found'] || []).reject { |issue| 
        issue.include?('JSON') || issue.include?('재검증')
      }
      
      # 토큰 사용량 정보 추출
      token_usage = data['token_usage']
      
      result = {
        validation_details: all_details,
        issues_found: issues,
        recommendations: data['recommendations'] || []
      }
      
      # 토큰 사용량 정보가 있으면 추가
      if token_usage
        result[:token_usage] = token_usage
      end
      
      # suggested_order 정보가 있으면 추가 (3단계용)
      if data['suggested_order']
        result[:suggested_order] = data['suggested_order']
        Rails.logger.info "parse_step_response에서 suggested_order 발견: #{data['suggested_order'].inspect}"
        Rails.logger.info "items_needing_receipts 포함 여부: #{data['suggested_order']['items_needing_receipts'].present?}"
        if data['suggested_order']['items_needing_receipts']
          Rails.logger.info "영수증 필요 항목 수: #{data['suggested_order']['items_needing_receipts'].size}"
        end
      end
      
      Rails.logger.info "[parse_step_response] 정상 반환 - result 타입: #{result.class.name}"
      return result
    rescue => e
      Rails.logger.error "단계 응답 파싱 중 예외 발생: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      
      # 기본 구조 반환
      fallback_result = {
        validation_details: items_data.map { |item| 
          { 
            'item_id' => item[:id],
            'item_name' => item[:expense_code],
            'status' => '미검증', 
            'message' => '검증 처리 중 오류'
          }
        },
        issues_found: [],
        recommendations: []
      }
      Rails.logger.info "[parse_step_response] 예외 처리 후 반환 - fallback_result 타입: #{fallback_result.class.name}"
      return fallback_result
    end
  
  # 단계별 결과 병합
  def merge_step_results(accumulated, step_result, expense_items)
    # validation_details 병합 (item_id 기준)
    step_result[:validation_details]&.each do |detail|
      existing = accumulated[:validation_details].find { |d| d['item_id'] == detail['item_id'] }
      if existing
        # 기존 결과와 병합 (확인 필요가 우선)
        if detail['status'] == '확인 필요'
          existing['status'] = detail['status']
          existing['message'] = "#{existing['message']}; #{detail['message']}"
        end
      else
        accumulated[:validation_details] << detail
      end
    end
    
    # issues_found 병합
    accumulated[:issues_found].concat(step_result[:issues_found] || [])
    
    # recommendations 병합
    accumulated[:recommendations].concat(step_result[:recommendations] || [])
    
    # 토큰 사용량 누적
    if step_result[:token_usage]
      accumulated[:token_usage][:total_tokens] += step_result[:token_usage][:total_tokens] || 0
      accumulated[:token_usage][:prompt_tokens] += step_result[:token_usage][:prompt_tokens] || 0
      accumulated[:token_usage][:completion_tokens] += step_result[:token_usage][:completion_tokens] || 0
    end
  end
  
  # 최종 결과 컴파일
  def compile_final_result(accumulated, expense_items)
    # 모든 항목이 검증되었는지 확인
    all_items_validated = expense_items.all? do |item|
      accumulated[:validation_details].any? { |d| d['item_id'] == item.id }
    end
    
    # 누락된 항목 추가
    expense_items.each do |item|
      unless accumulated[:validation_details].any? { |d| d['item_id'] == item.id }
        accumulated[:validation_details] << {
          'item_id' => item.id,
          'item_name' => item.expense_code.name,
          'status' => '완료',
          'message' => '모든 검증 통과'
        }
        
        item.update_columns(
          validation_status: 'validated',
          validation_message: '모든 검증 통과',
          validated_at: Time.current
        )
      end
    end
    
    # 전체 유효성 확인 (모든 항목이 '완료' 상태이고 영수증 문제가 없어야 함)
    all_valid = accumulated[:validation_details].all? { |d| 
      d['status'] == '완료' && 
      !d['message']&.include?('경고') && 
      !d['message']&.include?('주의') &&
      !d['message']&.include?('확인 필요') &&
      !d['message']&.include?('영수증 첨부 필요') &&
      !d['message']&.include?('영수증 첨부 필수') &&
      !d['message']&.include?('영수증 필요')
    }
    
    # 문제 있는 항목 수 계산
    problem_count = accumulated[:validation_details].count { |d| 
      d['status'] != '완료' || 
      d['message']&.include?('경고') || 
      d['message']&.include?('주의') ||
      d['message']&.include?('확인 필요') ||
      d['message']&.include?('영수증')
    }
    
    # 문제가 있는 항목의 세부 내용 수집
    problem_items = accumulated[:validation_details].select { |d| 
      d['status'] != '완료' || 
      d['message']&.include?('영수증 첨부 필요') ||
      d['message']&.include?('영수증 첨부 필수')
    }
    
    # 요약 생성 (더 구체적인 메시지)
    summary = if all_valid
      "모든 경비 항목이 검증을 통과했습니다."
    elsif problem_items.any?
      problems = []
      
      # 영수증 누락 항목 찾기
      receipt_missing = problem_items.select { |d| 
        d['message']&.include?('영수증') 
      }
      
      if receipt_missing.any?
        problems << "#{receipt_missing.size}개 항목에 영수증 첨부 필요"
      end
      
      # 기타 문제 항목
      other_problems = problem_items.reject { |d| 
        d['message']&.include?('영수증')
      }
      
      if other_problems.any?
        problems << "#{other_problems.size}개 항목에 검증 문제"
      end
      
      "❌ 검증 실패: #{problems.join(', ')}"
    else
      "#{problem_count}개 항목에서 문제가 발견되었습니다."
    end
    
    {
      validation_summary: summary,
      all_valid: all_valid,
      validation_details: accumulated[:validation_details],
      issues_found: accumulated[:issues_found].uniq,
      recommendations: accumulated[:recommendations].uniq,
      token_usage: accumulated[:token_usage],
      validated_at: Time.current
    }
  end
  
  # 진행 상황 브로드캐스트
  def broadcast_progress(step, name, status)
    # Turbo Streams를 통해 진행 상황 전송
    Turbo::StreamsChannel.broadcast_replace_to(
      "expense_sheet_#{@expense_sheet.id}_validation",
      target: "validation_step_#{step}",
      partial: "expense_sheets/validation_step",
      locals: { step: step, name: name, status: status }
    )
  rescue => e
    Rails.logger.error "진행 상황 브로드캐스트 실패: #{e.message}"
  end
end
end