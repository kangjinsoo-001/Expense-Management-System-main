# 경비 항목과 첨부파일 분석 결과를 비교 검증하는 서비스
class ValidationService
  attr_reader :expense_item, :attachment, :validation_rules

  def initialize(expense_item, attachment)
    @expense_item = expense_item
    @attachment = attachment
    @validation_rules = load_validation_rules
  end

  # 검증 실행 및 결과 반환
  def validate
    return validation_error("첨부파일이 없습니다") unless attachment
    return validation_error("AI 분석 결과가 없습니다") unless attachment.analysis_result.present?

    results = []
    overall_severity = 'pass'

    validation_rules.each do |rule|
      result = execute_validation_rule(rule)
      results << result
      
      # 가장 높은 심각도로 업데이트
      overall_severity = update_severity(overall_severity, result[:severity]) unless result[:passed]
    end

    {
      passed: overall_severity == 'pass',
      severity: overall_severity,
      results: results,
      validated_at: Time.current
    }
  end

  private

  def load_validation_rules
    # ExpenseItem을 통해 ExpenseCode의 validation_rules 로드
    return [] unless attachment.expense_item&.expense_code
    
    expense_code = attachment.expense_item.expense_code
    return [] unless expense_code.validation_rules.present?
    
    # ExpenseCode의 validation_rules에서 첨부파일 관련 규칙 추출
    # 현재는 빈 배열 반환 (향후 필요시 구현)
    []
  end

  def execute_validation_rule(rule)
    case rule.rule_type
    when 'amount_match'
      validate_amount_match(rule)
    when 'date_match'
      validate_date_match(rule)
    when 'vendor_match'
      validate_vendor_match(rule)
    when 'required_field'
      validate_required_field(rule)
    when 'category_match'
      validate_category_match(rule)
    when 'tax_validation'
      validate_tax_amount(rule)
    when 'custom'
      execute_custom_validation(rule)
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "알 수 없는 검증 타입: #{rule.rule_type}",
        severity: 'info'
      }
    end
  end

  # 금액 일치 검증
  def validate_amount_match(rule)
    analysis_amount = extract_amount_from_analysis
    item_amount = expense_item.amount

    if analysis_amount.nil?
      return {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "첨부파일에서 금액을 추출할 수 없습니다",
        severity: rule.severity || 'warning'
      }
    end

    # 허용 오차 (1원)
    tolerance = rule.tolerance || 1.0
    difference = (item_amount - analysis_amount).abs

    if difference <= tolerance
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "금액이 일치합니다",
        details: {
          item_amount: item_amount,
          attachment_amount: analysis_amount,
          difference: difference
        }
      }
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "금액이 일치하지 않습니다 (차이: #{number_to_currency(difference)})",
        severity: rule.severity || 'error',
        details: {
          item_amount: item_amount,
          attachment_amount: analysis_amount,
          difference: difference
        }
      }
    end
  end

  # 날짜 일치 검증
  def validate_date_match(rule)
    analysis_date = extract_date_from_analysis
    item_date = expense_item.incurred_on

    if analysis_date.nil?
      return {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "첨부파일에서 날짜를 추출할 수 없습니다",
        severity: rule.severity || 'warning'
      }
    end

    if analysis_date == item_date
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "날짜가 일치합니다",
        details: {
          item_date: item_date,
          attachment_date: analysis_date
        }
      }
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "날짜가 일치하지 않습니다",
        severity: rule.severity || 'warning',
        details: {
          item_date: item_date,
          attachment_date: analysis_date,
          difference_days: (item_date - analysis_date).to_i.abs
        }
      }
    end
  end

  # 업체명 일치 검증
  def validate_vendor_match(rule)
    analysis_vendor = extract_vendor_from_analysis
    item_vendor = expense_item.vendor_name

    if analysis_vendor.blank?
      return {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "첨부파일에서 업체명을 추출할 수 없습니다",
        severity: rule.severity || 'info'
      }
    end

    # 부분 일치 허용 (유사도 검증)
    if vendor_names_match?(item_vendor, analysis_vendor)
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "업체명이 일치합니다",
        details: {
          item_vendor: item_vendor,
          attachment_vendor: analysis_vendor
        }
      }
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "업체명이 일치하지 않습니다",
        severity: rule.severity || 'warning',
        details: {
          item_vendor: item_vendor,
          attachment_vendor: analysis_vendor
        }
      }
    end
  end

  # 필수 필드 존재 검증
  def validate_required_field(rule)
    field_name = rule.field_name
    field_value = attachment.analysis_result[field_name]

    if field_value.present?
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "필수 필드 '#{field_name}'가 존재합니다",
        details: {
          field_name: field_name,
          field_value: field_value
        }
      }
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "필수 필드 '#{field_name}'가 누락되었습니다",
        severity: rule.severity || 'error',
        details: {
          field_name: field_name
        }
      }
    end
  end

  # 카테고리 일치 검증
  def validate_category_match(rule)
    analysis_category = extract_category_from_analysis
    item_category = expense_item.expense_code&.name

    if analysis_category.blank?
      return {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,  # 카테고리는 선택사항
        message: "카테고리 정보를 확인할 수 없습니다",
        severity: 'info'
      }
    end

    if categories_match?(item_category, analysis_category)
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "카테고리가 일치합니다",
        details: {
          item_category: item_category,
          attachment_category: analysis_category
        }
      }
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "카테고리가 일치하지 않습니다",
        severity: rule.severity || 'info',
        details: {
          item_category: item_category,
          attachment_category: analysis_category
        }
      }
    end
  end

  # 세금 금액 검증
  def validate_tax_amount(rule)
    analysis_tax = extract_tax_from_analysis
    analysis_amount = extract_amount_from_analysis
    
    return {
      rule_id: rule.id,
      rule_type: rule.rule_type,
      passed: true,
      message: "세금 정보를 확인할 수 없습니다",
      severity: 'info'
    } if analysis_tax.nil? || analysis_amount.nil?

    # 부가세 10% 검증
    expected_tax = (analysis_amount / 11.0).round
    tax_difference = (analysis_tax - expected_tax).abs

    if tax_difference <= 1  # 1원 오차 허용
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "부가세가 올바르게 계산되었습니다",
        details: {
          total_amount: analysis_amount,
          tax_amount: analysis_tax,
          expected_tax: expected_tax
        }
      }
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "부가세 계산이 올바르지 않습니다",
        severity: rule.severity || 'warning',
        details: {
          total_amount: analysis_amount,
          tax_amount: analysis_tax,
          expected_tax: expected_tax,
          difference: tax_difference
        }
      }
    end
  end

  # 커스텀 검증 실행
  def execute_custom_validation(rule)
    # 자연어 규칙을 Ruby 코드로 변환하여 실행
    # 보안을 위해 제한된 컨텍스트에서 실행
    begin
      result = evaluate_custom_rule(rule.prompt_text)
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: result,
        message: rule.prompt_text,
        severity: result ? nil : (rule.severity || 'warning')
      }
    rescue => e
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "커스텀 규칙 실행 실패: #{e.message}",
        severity: 'error'
      }
    end
  end

  # 분석 결과에서 금액 추출
  def extract_amount_from_analysis
    result = attachment.analysis_result
    return nil unless result

    # 다양한 필드명 시도
    amount = result['total_amount'] || 
             result['amount'] || 
             result['총금액'] ||
             result['금액']
    
    return nil unless amount
    amount.to_s.gsub(/[^0-9.-]/, '').to_f
  end

  # 분석 결과에서 날짜 추출
  def extract_date_from_analysis
    result = attachment.analysis_result
    return nil unless result

    date_str = result['date'] || 
               result['transaction_date'] || 
               result['거래일자'] ||
               result['날짜']
    
    return nil unless date_str
    Date.parse(date_str.to_s) rescue nil
  end

  # 분석 결과에서 업체명 추출
  def extract_vendor_from_analysis
    result = attachment.analysis_result
    return nil unless result

    result['vendor_name'] || 
    result['vendor'] || 
    result['merchant'] ||
    result['업체명'] ||
    result['상호명']
  end

  # 분석 결과에서 카테고리 추출
  def extract_category_from_analysis
    result = attachment.analysis_result
    return nil unless result

    result['category'] || 
    result['expense_type'] || 
    result['카테고리'] ||
    result['경비유형']
  end

  # 분석 결과에서 세금 추출
  def extract_tax_from_analysis
    result = attachment.analysis_result
    return nil unless result

    tax = result['tax_amount'] || 
          result['vat'] || 
          result['부가세'] ||
          result['세금']
    
    return nil unless tax
    tax.to_s.gsub(/[^0-9.-]/, '').to_f
  end

  # 업체명 일치 여부 확인 (유사도 검증)
  def vendor_names_match?(name1, name2)
    return false if name1.blank? || name2.blank?
    
    # 정확히 일치
    return true if name1.downcase == name2.downcase
    
    # 부분 문자열 포함
    return true if name1.downcase.include?(name2.downcase) || 
                   name2.downcase.include?(name1.downcase)
    
    # 레벤슈타인 거리 계산 (유사도)
    similarity = calculate_similarity(name1.downcase, name2.downcase)
    similarity >= 0.8  # 80% 이상 유사
  end

  # 카테고리 일치 여부 확인
  def categories_match?(cat1, cat2)
    return false if cat1.blank? || cat2.blank?
    
    # 정확히 일치
    return true if cat1.downcase == cat2.downcase
    
    # 부분 문자열 포함
    cat1.downcase.include?(cat2.downcase) || cat2.downcase.include?(cat1.downcase)
  end

  # 문자열 유사도 계산 (0.0 ~ 1.0)
  def calculate_similarity(str1, str2)
    return 1.0 if str1 == str2
    return 0.0 if str1.empty? || str2.empty?
    
    # 간단한 Jaccard 유사도
    chars1 = str1.chars.to_set
    chars2 = str2.chars.to_set
    
    intersection = chars1 & chars2
    union = chars1 | chars2
    
    intersection.size.to_f / union.size.to_f
  end

  # 커스텀 규칙 평가 (제한된 컨텍스트)
  def evaluate_custom_rule(rule_text)
    # 간단한 규칙 패턴 매칭
    case rule_text.downcase
    when /금액.*이상/, /amount.*greater/
      amount = extract_amount_from_analysis
      threshold = rule_text.scan(/\d+/).first.to_f
      amount && amount >= threshold
    when /날짜.*이내/, /within.*days/
      date = extract_date_from_analysis
      days = rule_text.scan(/\d+/).first.to_i
      date && (Date.current - date).abs <= days
    else
      # 기본값: 통과
      true
    end
  end

  # 심각도 업데이트
  def update_severity(current, new_severity)
    severity_levels = {
      'pass' => 0,
      'info' => 1,
      'warning' => 2,
      'error' => 3
    }
    
    current_level = severity_levels[current] || 0
    new_level = severity_levels[new_severity] || 0
    
    new_level > current_level ? new_severity : current
  end

  # 검증 오류 응답
  def validation_error(message)
    {
      passed: false,
      severity: 'error',
      results: [{
        passed: false,
        message: message,
        severity: 'error'
      }],
      validated_at: Time.current
    }
  end

  # 통화 형식 변환
  def number_to_currency(amount)
    "₩#{amount.to_i.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')}"
  end
end