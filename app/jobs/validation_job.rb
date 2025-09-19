# AI 분석 결과와 경비 항목을 비교 검증하는 백그라운드 작업
class ValidationJob < ApplicationJob
  queue_as :default
  
  # 재시도 설정
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(expense_item_id, attachment_id = nil)
    expense_item = ExpenseItem.find_by(id: expense_item_id)
    return unless expense_item

    Rails.logger.info "검증 시작: ExpenseItem ##{expense_item_id}"

    # 첨부파일이 지정되지 않은 경우 가장 최근 첨부파일 사용
    if attachment_id
      attachment = expense_item.expense_attachments.find_by(id: attachment_id)
    else
      attachment = expense_item.expense_attachments
                              .where.not(analysis_result: nil)
                              .order(created_at: :desc)
                              .first
    end

    if attachment.nil?
      Rails.logger.info "검증할 첨부파일이 없음: ExpenseItem ##{expense_item_id}"
      update_item_validation_status(expense_item, nil, 'no_attachment')
      return
    end

    # ValidationService를 사용하여 검증 실행
    validator = ValidationService.new(expense_item, attachment)
    validation_result = validator.validate

    # 검증 결과 저장
    save_validation_result(expense_item, attachment, validation_result)

    # 실시간 업데이트 브로드캐스트
    broadcast_validation_complete(expense_item, validation_result)

    Rails.logger.info "검증 완료: ExpenseItem ##{expense_item_id}, 결과: #{validation_result[:severity]}"
  end

  private

  def save_validation_result(expense_item, attachment, validation_result)
    # 첨부파일에 검증 결과 저장
    attachment.update!(
      validation_result: validation_result,
      validation_passed: validation_result[:passed]
    )

    # 경비 항목에 검증 상태 업데이트
    update_item_validation_status(expense_item, validation_result)
  end

  def update_item_validation_status(expense_item, validation_result, reason = nil)
    if reason == 'no_attachment'
      expense_item.update!(
        validation_status: 'pending',
        validation_message: '첨부파일이 없습니다'
      )
    elsif validation_result.nil?
      expense_item.update!(
        validation_status: 'pending',
        validation_message: '검증 대기중'
      )
    else
      status = case validation_result[:severity]
               when 'pass'
                 'validated'
               when 'info'
                 'validated'
               when 'warning'
                 'warning'
               when 'error'
                 'failed'
               else
                 'pending'
               end

      expense_item.update!(
        validation_status: status,
        validation_message: build_validation_message(validation_result),
        validated_at: validation_result[:validated_at]
      )
    end
  end

  def build_validation_message(validation_result)
    failed_rules = validation_result[:results].select { |r| !r[:passed] }
    
    if failed_rules.empty?
      "모든 검증을 통과했습니다"
    else
      messages = failed_rules.map { |r| r[:message] }
      messages.join(", ")
    end
  end

  def broadcast_validation_complete(expense_item, validation_result)
    # Turbo Streams로 실시간 업데이트
    Turbo::StreamsChannel.broadcast_update_to(
      "expense_item_#{expense_item.id}",
      target: "expense_item_#{expense_item.id}_validation",
      partial: "expense_items/validation_status",
      locals: { 
        expense_item: expense_item,
        validation_result: validation_result
      }
    )

    # 경비 시트 전체 상태 업데이트
    Turbo::StreamsChannel.broadcast_update_to(
      "expense_sheet_#{expense_item.expense_sheet_id}",
      target: "expense_sheet_validation_summary",
      partial: "expense_sheets/validation_summary",
      locals: { expense_sheet: expense_item.expense_sheet }
    )
  end
end