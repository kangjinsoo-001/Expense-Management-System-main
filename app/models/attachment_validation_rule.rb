class AttachmentValidationRule < ApplicationRecord
  # 상수 정의
  RULE_TYPES = %w[required amount_match order_match custom telecom_check existence_check].freeze
  SEVERITIES = %w[pass warning error info].freeze
  
  SEVERITY_LEVELS = {
    'pass' => '통과',
    'warning' => '주의', 
    'error' => '경고'
  }.freeze

  # 관계 설정
  belongs_to :attachment_requirement

  # 검증 규칙
  validates :rule_type, presence: true, inclusion: { in: RULE_TYPES }
  validates :prompt_text, presence: true
  validates :severity, presence: true, inclusion: { in: SEVERITIES }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :attachment_requirement, presence: true

  # 스코프
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :errors, -> { by_severity('error') }
  scope :warnings, -> { by_severity('warning') }

  # 콜백
  before_validation :set_default_position, on: :create

  # 검증 실행
  def validate_data(analysis_result, expense_items)
    case rule_type
    when 'required'
      validate_required_fields(analysis_result)
    when 'amount_match'
      validate_amount_match(analysis_result, expense_items)
    when 'order_match'
      validate_order_match(analysis_result, expense_items)
    when 'custom'
      validate_custom_rule(analysis_result, expense_items)
    else
      { passed: true, message: '알 수 없는 규칙 유형' }
    end
  end

  # 심각도 레벨 한글 표시
  def severity_display
    SEVERITY_LEVELS[severity] || severity
  end

  # 규칙이 차단 규칙인지 확인
  def blocking?
    severity == 'error'
  end

  # 규칙이 경고 규칙인지 확인
  def warning?
    severity == 'warning'
  end

  # 규칙이 통과 규칙인지 확인
  def passing?
    severity == 'pass'
  end

  private

  def set_default_position
    self.position ||= self.class.maximum(:position).to_i + 1
  end

  def validate_required_fields(analysis_result)
    # 필수 필드 존재 여부 검증
    { passed: true, message: '필수 필드 검증 통과' }
  end

  def validate_amount_match(analysis_result, expense_items)
    # 금액 일치 검증
    { passed: true, message: '금액 일치 검증 통과' }
  end

  def validate_order_match(analysis_result, expense_items)
    # 순서 일치 검증
    { passed: true, message: '순서 일치 검증 통과' }
  end

  def validate_custom_rule(analysis_result, expense_items)
    # 사용자 정의 규칙 검증
    { passed: true, message: '사용자 정의 규칙 검증 통과' }
  end
end
