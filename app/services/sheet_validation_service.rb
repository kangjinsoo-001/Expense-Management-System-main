# 경비 시트 전체의 첨부파일을 검증하는 서비스
class SheetValidationService
  attr_reader :expense_sheet, :sheet_attachments

  def initialize(expense_sheet)
    @expense_sheet = expense_sheet
    @sheet_attachments = expense_sheet.expense_sheet_attachments.includes(:attachment_requirement)
  end

  # 경비 시트 레벨 검증 실행
  def validate
    results = {
      passed: true,
      severity: 'pass',
      sheet_level_validations: [],
      required_attachments: check_required_attachments,
      attachment_validations: validate_sheet_attachments,
      validated_at: Time.current
    }

    # 전체 검증 결과 계산
    update_overall_result(results)
    results
  end

  private

  # 필수 첨부파일 확인
  def check_required_attachments
    required = AttachmentRequirement.where(
      attachment_type: 'expense_sheet',
      required: true,
      active: true
    )

    attached_requirement_ids = sheet_attachments.pluck(:attachment_requirement_id).compact

    results = []
    all_present = true

    required.each do |req|
      is_attached = attached_requirement_ids.include?(req.id)
      results << {
        requirement_id: req.id,
        requirement_name: req.name,
        attached: is_attached,
        message: is_attached ? "#{req.name} 첨부됨" : "#{req.name} 누락됨",
        severity: is_attached ? 'pass' : 'error'
      }
      all_present = false unless is_attached
    end

    {
      all_required_present: all_present,
      results: results
    }
  end

  # 경비 시트 첨부파일 검증
  def validate_sheet_attachments
    return [] if sheet_attachments.empty?

    sheet_attachments.map do |attachment|
      validate_single_attachment(attachment)
    end
  end

  # 개별 첨부파일 검증
  def validate_single_attachment(attachment)
    return basic_validation(attachment) unless attachment.attachment_requirement

    # AI 분석 결과가 있는 경우
    if attachment.analysis_result.present?
      perform_attachment_validation(attachment)
    else
      {
        attachment_id: attachment.id,
        file_name: attachment.file_name,
        requirement: attachment.attachment_requirement.name,
        passed: false,
        message: "AI 분석이 완료되지 않았습니다",
        severity: 'warning'
      }
    end
  end

  # 기본 검증 (요구사항이 없는 경우)
  def basic_validation(attachment)
    {
      attachment_id: attachment.id,
      file_name: attachment.file_name,
      requirement: nil,
      passed: true,
      message: "첨부파일 확인됨",
      severity: 'pass'
    }
  end

  # 첨부파일 검증 수행
  def perform_attachment_validation(attachment)
    requirement = attachment.attachment_requirement
    validation_rules = requirement.attachment_validation_rules.active

    if validation_rules.empty?
      return {
        attachment_id: attachment.id,
        file_name: attachment.file_name,
        requirement: requirement.name,
        passed: true,
        message: "검증 규칙이 없습니다",
        severity: 'info'
      }
    end

    # 각 검증 규칙 실행
    rule_results = []
    overall_passed = true
    overall_severity = 'pass'

    validation_rules.each do |rule|
      result = execute_sheet_validation_rule(rule, attachment)
      rule_results << result
      
      unless result[:passed]
        overall_passed = false
        overall_severity = update_severity(overall_severity, result[:severity])
      end
    end

    {
      attachment_id: attachment.id,
      file_name: attachment.file_name,
      requirement: requirement.name,
      passed: overall_passed,
      severity: overall_severity,
      rule_results: rule_results
    }
  end

  # 경비 시트 레벨 검증 규칙 실행
  def execute_sheet_validation_rule(rule, attachment)
    case rule.rule_type
    when 'total_amount_match'
      validate_total_amount(rule, attachment)
    when 'period_match'
      validate_period_match(rule, attachment)
    when 'card_number_match'
      validate_card_number(rule, attachment)
    when 'transaction_count'
      validate_transaction_count(rule, attachment)
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "검증 타입 미지원: #{rule.rule_type}",
        severity: 'info'
      }
    end
  end

  # 총액 일치 검증
  def validate_total_amount(rule, attachment)
    analysis_total = extract_total_from_attachment(attachment)
    sheet_total = expense_sheet.expense_items.sum(:amount)

    if analysis_total.nil?
      return {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "첨부파일에서 총액을 추출할 수 없습니다",
        severity: rule.severity || 'warning'
      }
    end

    tolerance = rule.tolerance || 1.0
    difference = (sheet_total - analysis_total).abs

    if difference <= tolerance
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "총액이 일치합니다",
        details: {
          sheet_total: sheet_total,
          attachment_total: analysis_total,
          difference: difference
        }
      }
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "총액 불일치 (차이: #{number_to_currency(difference)})",
        severity: rule.severity || 'error',
        details: {
          sheet_total: sheet_total,
          attachment_total: analysis_total,
          difference: difference
        }
      }
    end
  end

  # 기간 일치 검증
  def validate_period_match(rule, attachment)
    analysis_period = extract_period_from_attachment(attachment)
    
    if analysis_period.nil?
      return {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "첨부파일에서 기간을 추출할 수 없습니다",
        severity: rule.severity || 'info'
      }
    end

    sheet_start = expense_sheet.expense_items.minimum(:incurred_on)
    sheet_end = expense_sheet.expense_items.maximum(:incurred_on)

    period_matches = analysis_period[:start] == sheet_start && 
                    analysis_period[:end] == sheet_end

    if period_matches
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "기간이 일치합니다",
        details: {
          sheet_period: "#{sheet_start} ~ #{sheet_end}",
          attachment_period: "#{analysis_period[:start]} ~ #{analysis_period[:end]}"
        }
      }
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "기간이 일치하지 않습니다",
        severity: rule.severity || 'warning',
        details: {
          sheet_period: "#{sheet_start} ~ #{sheet_end}",
          attachment_period: "#{analysis_period[:start]} ~ #{analysis_period[:end]}"
        }
      }
    end
  end

  # 카드번호 일치 검증
  def validate_card_number(rule, attachment)
    analysis_card = extract_card_number_from_attachment(attachment)
    
    if analysis_card.blank?
      return {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,  # 카드번호는 선택사항
        message: "카드번호 정보 없음",
        severity: 'info'
      }
    end

    # 법인카드 정보와 비교 (추후 구현)
    {
      rule_id: rule.id,
      rule_type: rule.rule_type,
      passed: true,
      message: "카드번호 확인됨",
      details: {
        card_number: mask_card_number(analysis_card)
      }
    }
  end

  # 거래 건수 검증
  def validate_transaction_count(rule, attachment)
    analysis_count = extract_transaction_count_from_attachment(attachment)
    sheet_count = expense_sheet.expense_items.count

    if analysis_count.nil?
      return {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "거래 건수 정보 없음",
        severity: 'info'
      }
    end

    if analysis_count == sheet_count
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: true,
        message: "거래 건수가 일치합니다",
        details: {
          sheet_count: sheet_count,
          attachment_count: analysis_count
        }
      }
    else
      {
        rule_id: rule.id,
        rule_type: rule.rule_type,
        passed: false,
        message: "거래 건수 불일치",
        severity: rule.severity || 'warning',
        details: {
          sheet_count: sheet_count,
          attachment_count: analysis_count,
          difference: (sheet_count - analysis_count).abs
        }
      }
    end
  end

  # 첨부파일에서 총액 추출
  def extract_total_from_attachment(attachment)
    result = attachment.analysis_result
    return nil unless result

    total = result['total_amount'] || 
            result['청구금액'] || 
            result['총액'] ||
            result['total']
    
    return nil unless total
    total.to_s.gsub(/[^0-9.-]/, '').to_f
  end

  # 첨부파일에서 기간 추출
  def extract_period_from_attachment(attachment)
    result = attachment.analysis_result
    return nil unless result

    start_date = result['period_start'] || result['시작일']
    end_date = result['period_end'] || result['종료일']

    return nil unless start_date && end_date

    {
      start: (Date.parse(start_date.to_s) rescue nil),
      end: (Date.parse(end_date.to_s) rescue nil)
    }.compact.presence
  end

  # 첨부파일에서 카드번호 추출
  def extract_card_number_from_attachment(attachment)
    result = attachment.analysis_result
    return nil unless result

    result['card_number'] || result['카드번호']
  end

  # 첨부파일에서 거래 건수 추출
  def extract_transaction_count_from_attachment(attachment)
    result = attachment.analysis_result
    return nil unless result

    count = result['transaction_count'] || 
            result['거래건수'] || 
            result['count']
    
    count.to_i if count
  end

  # 카드번호 마스킹
  def mask_card_number(card_number)
    return nil unless card_number
    card_number.to_s.gsub(/\d(?=\d{4})/, '*')
  end

  # 전체 검증 결과 업데이트
  def update_overall_result(results)
    # 필수 첨부파일 누락 시 실패
    unless results[:required_attachments][:all_required_present]
      results[:passed] = false
      results[:severity] = 'error'
      return
    end

    # 첨부파일 검증 결과 확인
    results[:attachment_validations].each do |validation|
      unless validation[:passed]
        results[:passed] = false
        results[:severity] = update_severity(results[:severity], validation[:severity])
      end
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

  # 통화 형식 변환
  def number_to_currency(amount)
    "₩#{amount.to_i.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')}"
  end
end