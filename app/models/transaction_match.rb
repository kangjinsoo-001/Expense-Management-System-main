class TransactionMatch < ApplicationRecord
  belongs_to :pdf_analysis_result
  belongs_to :expense_item
  
  validates :transaction_data, presence: true
  validates :confidence, presence: true, 
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :match_type, presence: true, 
            inclusion: { in: %w[exact amount_similar text_similar manual] }
  
  scope :confirmed, -> { where(is_confirmed: true) }
  scope :unconfirmed, -> { where(is_confirmed: false) }
  scope :high_confidence, -> { where('confidence >= ?', 0.8) }
  scope :low_confidence, -> { where('confidence < ?', 0.6) }
  
  # 매치 확인
  def confirm!
    update!(is_confirmed: true)
  end
  
  # 매치 취소
  def reject!
    destroy
  end
  
  # 거래 날짜
  def transaction_date
    # 테스트 코드에서 string으로 전달하는 경우도 처리
    date_value = transaction_data&.dig('date')
    return date_value if date_value.is_a?(String)
    date_value&.to_date
  end
  
  # 거래 금액
  def transaction_amount
    transaction_data&.dig('amount')&.to_f
  end
  
  # 거래 설명
  def transaction_description
    transaction_data&.dig('description')
  end
  
  # 매치가 정확한지 확인
  def accurate?
    return false unless expense_item.present?
    
    date_match = transaction_date == expense_item.expense_date
    amount_match = (transaction_amount - expense_item.amount).abs < 0.01
    
    date_match && amount_match
  end
  
  # 신뢰도 레벨 판단
  def high_confidence?
    confidence >= 0.9
  end
  
  def medium_confidence?
    confidence >= 0.7 && confidence < 0.9
  end
  
  def low_confidence?
    confidence < 0.7
  end
  
  # 경비 항목과의 금액 차이
  def amount_difference
    return 0 unless expense_item && transaction_amount
    (expense_item.amount - transaction_amount).abs
  end
  
  def amount_difference_percentage
    return 0 unless expense_item && transaction_amount && expense_item.amount > 0
    (amount_difference / expense_item.amount * 100).round(2)
  end
  
  # 매칭 타입 라벨
  def match_type_label
    case match_type
    when 'exact'
      '정확히 일치'
    when 'amount_similar'
      '금액 유사'
    when 'text_similar'
      '설명 유사'
    else
      match_type
    end
  end
  
  # 필요한 MATCH_TYPES 상수
  MATCH_TYPES = %w[exact amount_similar text_similar manual].freeze
  
  # 고유성 검증을 위한 추가 검증
  validates :expense_item_id, uniqueness: { scope: :pdf_analysis_result_id }
end
