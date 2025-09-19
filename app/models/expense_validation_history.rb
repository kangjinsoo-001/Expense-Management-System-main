class ExpenseValidationHistory < ApplicationRecord
  belongs_to :expense_sheet
  belongs_to :validated_by, class_name: 'User'
  
  # 최신 순으로 정렬
  scope :recent, -> { order(created_at: :desc) }
  
  # 조회 권한 체크 메서드
  def viewable_by?(user)
    # 본인 또는 어드민만 조회 가능
    expense_sheet.user_id == user.id || user.admin?
  end
  
  # 검증 상태를 한글로 표시
  def status_label
    all_valid ? '검증 완료' : '확인 필요'
  end
  
  # 확인 필요한 항목 개수 (영수증 누락 포함)
  def warning_count
    return 0 unless validation_details.is_a?(Array)
    
    # 확인 필요 상태이거나 영수증 누락 메시지가 있는 항목 수
    validation_details.count { |d| 
      d['status'] == '확인 필요' || 
      d['message']&.include?('영수증 첨부 필요') ||
      d['message']&.include?('영수증 첨부 필수') ||
      d['message']&.include?('영수증 필요')
    }
  end
  
  # 검증 완료된 항목 개수
  def validated_count
    return 0 unless validation_details.is_a?(Array)
    validation_details.count { |d| d['status'] == '완료' }
  end
  
  # 미검증 항목 개수
  def pending_count
    return 0 unless validation_details.is_a?(Array)
    validation_details.count { |d| d['status'] == '미검증' }
  end
end