# 경비 시트 전체의 첨부파일을 검증하는 백그라운드 작업
class SheetValidationJob < ApplicationJob
  queue_as :default
  
  # 재시도 설정
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(expense_sheet_id)
    expense_sheet = ExpenseSheet.find_by(id: expense_sheet_id)
    return unless expense_sheet

    Rails.logger.info "경비 시트 검증 시작: ExpenseSheet ##{expense_sheet_id}"

    # SheetValidationService를 사용하여 검증 실행
    validator = SheetValidationService.new(expense_sheet)
    validation_result = validator.validate

    # 검증 결과 저장
    save_sheet_validation_result(expense_sheet, validation_result)

    # 개별 경비 항목 검증도 트리거
    trigger_item_validations(expense_sheet) if validation_result[:passed]

    # 실시간 업데이트 브로드캐스트
    broadcast_sheet_validation_complete(expense_sheet, validation_result)

    Rails.logger.info "경비 시트 검증 완료: ExpenseSheet ##{expense_sheet_id}, 결과: #{validation_result[:severity]}"
  end

  private

  def save_sheet_validation_result(expense_sheet, validation_result)
    # 경비 시트에 검증 결과 저장
    expense_sheet.update!(
      validation_result: validation_result,
      validation_status: determine_validation_status(validation_result),
      validated_at: validation_result[:validated_at]
    )
  end

  def determine_validation_status(validation_result)
    case validation_result[:severity]
    when 'pass'
      'validated'
    when 'info'
      'validated'
    when 'warning'
      'needs_review'
    when 'error'
      'failed'
    else
      'pending'
    end
  end

  def trigger_item_validations(expense_sheet)
    # 각 경비 항목에 대해 검증 Job 실행
    expense_sheet.expense_items.each do |item|
      next unless item.expense_attachments.any?
      
      ValidationJob.perform_later(item.id)
    end
  end

  def broadcast_sheet_validation_complete(expense_sheet, validation_result)
    # Turbo Streams로 실시간 업데이트
    Turbo::StreamsChannel.broadcast_update_to(
      "expense_sheet_#{expense_sheet.id}",
      target: "expense_sheet_validation_result",
      partial: "expense_sheets/sheet_validation_result",
      locals: { 
        expense_sheet: expense_sheet,
        validation_result: validation_result
      }
    )

    # 검증 상태 배지 업데이트
    Turbo::StreamsChannel.broadcast_update_to(
      "expense_sheet_#{expense_sheet.id}",
      target: "expense_sheet_#{expense_sheet.id}_status",
      partial: "expense_sheets/validation_badge",
      locals: { expense_sheet: expense_sheet }
    )
  end
end