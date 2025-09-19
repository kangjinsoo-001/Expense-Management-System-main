# 검증 결과에 따른 처리를 담당하는 서비스
class ValidationResultHandler
  attr_reader :expense_item, :validation_result

  def initialize(expense_item, validation_result)
    @expense_item = expense_item
    @validation_result = validation_result
  end

  # 검증 결과에 따른 처리 수행
  def handle
    case validation_result[:severity]
    when 'pass'
      handle_pass
    when 'info'
      handle_info
    when 'warning'
      handle_warning
    when 'error'
      handle_error
    else
      handle_unknown
    end
  end

  private

  # 검증 통과 처리
  def handle_pass
    Rails.logger.info "검증 통과: ExpenseItem ##{expense_item.id}"
    
    # 검증 상태 업데이트
    expense_item.update!(
      validation_status: 'validated',
      validation_message: '모든 검증을 통과했습니다',
      validated_at: Time.current
    )
    
    # 경비 시트가 제출 가능한 상태인지 확인
    check_sheet_readiness
    
    # 성공 알림 발송 (선택적)
    notify_validation_success if should_notify?
    
    { success: true, action: 'proceed' }
  end

  # 정보성 검증 결과 처리
  def handle_info
    Rails.logger.info "검증 정보: ExpenseItem ##{expense_item.id}"
    
    messages = validation_result[:results]
                .select { |r| r[:severity] == 'info' }
                .map { |r| r[:message] }
    
    expense_item.update!(
      validation_status: 'validated',
      validation_message: messages.join(', '),
      validated_at: Time.current
    )
    
    check_sheet_readiness
    
    { success: true, action: 'proceed' }
  end

  # 경고 수준 검증 결과 처리
  def handle_warning
    Rails.logger.warn "검증 경고: ExpenseItem ##{expense_item.id}"
    
    warning_messages = validation_result[:results]
                       .select { |r| r[:severity] == 'warning' }
                       .map { |r| r[:message] }
    
    expense_item.update!(
      validation_status: 'warning',
      validation_message: warning_messages.join(', '),
      validated_at: Time.current
    )
    
    # 사용자 확인 필요 플래그 설정
    expense_item.update!(requires_user_confirmation: true)
    
    # 경고 알림 발송
    notify_validation_warning(warning_messages)
    
    { 
      success: false, 
      action: 'user_confirmation_required',
      warnings: warning_messages,
      can_override: true
    }
  end

  # 오류 수준 검증 결과 처리
  def handle_error
    Rails.logger.error "검증 실패: ExpenseItem ##{expense_item.id}"
    
    error_messages = validation_result[:results]
                     .select { |r| r[:severity] == 'error' }
                     .map { |r| r[:message] }
    
    expense_item.update!(
      validation_status: 'failed',
      validation_message: error_messages.join(', '),
      validated_at: Time.current
    )
    
    # 제출 차단 플래그 설정
    expense_item.update!(submission_blocked: true)
    
    # 오류 알림 발송
    notify_validation_error(error_messages)
    
    # 자동 수정 시도 (가능한 경우)
    auto_fix_attempts = attempt_auto_fix(validation_result[:results])
    
    { 
      success: false, 
      action: 'correction_required',
      errors: error_messages,
      can_override: false,
      auto_fix_attempts: auto_fix_attempts
    }
  end

  # 알 수 없는 검증 결과 처리
  def handle_unknown
    Rails.logger.warn "알 수 없는 검증 결과: ExpenseItem ##{expense_item.id}"
    
    expense_item.update!(
      validation_status: 'pending',
      validation_message: '검증 결과를 해석할 수 없습니다',
      validated_at: Time.current
    )
    
    { success: false, action: 'manual_review_required' }
  end

  # 경비 시트 제출 준비 상태 확인
  def check_sheet_readiness
    sheet = expense_item.expense_sheet
    return unless sheet
    
    # 모든 항목이 검증되었는지 확인
    if sheet.all_items_validated?
      sheet.update!(ready_for_submission: true)
      broadcast_sheet_ready(sheet)
    end
  end

  # 자동 수정 시도
  def attempt_auto_fix(validation_results)
    auto_fix_attempts = []
    
    validation_results.each do |result|
      next if result[:passed]
      
      case result[:rule_type]
      when 'amount_match'
        # 금액 불일치 자동 수정 시도
        if can_auto_fix_amount?(result)
          fix_result = auto_fix_amount(result)
          auto_fix_attempts << fix_result
        end
      when 'date_match'
        # 날짜 불일치 자동 수정 시도
        if can_auto_fix_date?(result)
          fix_result = auto_fix_date(result)
          auto_fix_attempts << fix_result
        end
      end
    end
    
    auto_fix_attempts
  end

  # 금액 자동 수정 가능 여부 확인
  def can_auto_fix_amount?(result)
    return false unless result[:details]
    
    difference = result[:details][:difference]
    # 10원 이하 차이는 자동 수정 가능
    difference && difference <= 10
  end

  # 금액 자동 수정
  def auto_fix_amount(result)
    attachment_amount = result[:details][:attachment_amount]
    
    if expense_item.update(amount: attachment_amount)
      {
        rule_type: 'amount_match',
        fixed: true,
        message: "금액을 #{attachment_amount}으로 자동 수정했습니다"
      }
    else
      {
        rule_type: 'amount_match',
        fixed: false,
        message: "금액 자동 수정 실패"
      }
    end
  end

  # 날짜 자동 수정 가능 여부 확인
  def can_auto_fix_date?(result)
    return false unless result[:details]
    
    difference_days = result[:details][:difference_days]
    # 1일 차이는 자동 수정 가능
    difference_days && difference_days <= 1
  end

  # 날짜 자동 수정
  def auto_fix_date(result)
    attachment_date = result[:details][:attachment_date]
    
    if expense_item.update(expense_date: attachment_date)
      {
        rule_type: 'date_match',
        fixed: true,
        message: "날짜를 #{attachment_date}로 자동 수정했습니다"
      }
    else
      {
        rule_type: 'date_match',
        fixed: false,
        message: "날짜 자동 수정 실패"
      }
    end
  end

  # 알림 발송 여부 결정
  def should_notify?
    # 환경 설정 또는 사용자 설정에 따라 결정
    Rails.env.production? || expense_item.expense_sheet.user.notification_enabled?
  rescue
    false
  end

  # 검증 성공 알림
  def notify_validation_success
    NotificationService.send_validation_success(
      user: expense_item.expense_sheet.user,
      expense_item: expense_item
    )
  rescue => e
    Rails.logger.error "알림 발송 실패: #{e.message}"
  end

  # 검증 경고 알림
  def notify_validation_warning(warnings)
    NotificationService.send_validation_warning(
      user: expense_item.expense_sheet.user,
      expense_item: expense_item,
      warnings: warnings
    )
  rescue => e
    Rails.logger.error "경고 알림 발송 실패: #{e.message}"
  end

  # 검증 오류 알림
  def notify_validation_error(errors)
    NotificationService.send_validation_error(
      user: expense_item.expense_sheet.user,
      expense_item: expense_item,
      errors: errors
    )
  rescue => e
    Rails.logger.error "오류 알림 발송 실패: #{e.message}"
  end

  # 경비 시트 준비 완료 브로드캐스트
  def broadcast_sheet_ready(sheet)
    Turbo::StreamsChannel.broadcast_update_to(
      "expense_sheet_#{sheet.id}",
      target: "expense_sheet_#{sheet.id}_submit_button",
      partial: "expense_sheets/submit_button",
      locals: { expense_sheet: sheet }
    )
  end
end