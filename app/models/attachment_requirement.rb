class AttachmentRequirement < ApplicationRecord
  # 첨부파일 타입 정의
  ATTACHMENT_TYPES = {
    expense_item: 'expense_item',     # 경비 항목 첨부파일 (영수증 등)
    expense_sheet: 'expense_sheet'    # 경비 시트 첨부파일 (법인카드 명세서 등)
  }.freeze
  
  # 관계 설정
  has_many :attachment_analysis_rules, dependent: :destroy
  has_many :attachment_validation_rules, dependent: :destroy
  has_many :expense_sheet_attachments, dependent: :nullify
  
  # 별칭 설정 (컨트롤러에서 사용하는 이름과 매칭)
  has_many :analysis_rules, class_name: 'AttachmentAnalysisRule', dependent: :destroy
  has_many :validation_rules, class_name: 'AttachmentValidationRule', dependent: :destroy
  
  # 중첩 속성 허용
  accepts_nested_attributes_for :analysis_rules, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :validation_rules, reject_if: :all_blank, allow_destroy: true

  # 검증 규칙
  validates :name, presence: true, uniqueness: { scope: :attachment_type, case_sensitive: false }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :attachment_type, presence: true, inclusion: { in: ATTACHMENT_TYPES.values }
  
  # 스코프
  scope :active, -> { where(active: true) }
  scope :required, -> { where(required: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }
  scope :for_expense_items, -> { where(attachment_type: ATTACHMENT_TYPES[:expense_item]) }
  scope :for_expense_sheets, -> { where(attachment_type: ATTACHMENT_TYPES[:expense_sheet]) }

  # JSON 필드 처리
  serialize :file_types, coder: JSON, type: Array

  # 콜백
  before_validation :set_default_position, on: :create

  # 파일 타입 검증
  def accepts_file_type?(file_type)
    return true if file_types.blank?
    
    extension = file_type.to_s.downcase.delete('.')
    file_types.map(&:downcase).include?(extension)
  end
  
  # 허용된 파일 타입을 accept 속성 형식으로 반환
  def allowed_file_types
    return "application/pdf,image/*" if file_types.blank?
    
    file_types.map do |type|
      case type.downcase
      when 'pdf'
        'application/pdf'
      when 'jpg', 'jpeg'
        'image/jpeg'
      when 'png'
        'image/png'
      when 'gif'
        'image/gif'
      else
        ".#{type}"
      end
    end.join(',')
  end

  # 조건 평가
  def condition_met?(expense_sheet)
    return true if condition_expression.blank?
    
    # 조건식 평가 로직 (추후 구현)
    # 예: "expense_codes.include?('TRAVEL')"
    true
  end

  # 이 요구사항이 특정 경비 시트에 적용되는지 확인
  def applicable_to?(expense_sheet)
    active? && condition_met?(expense_sheet)
  end
  
  # 타입별 라벨 반환
  def attachment_type_label
    case attachment_type
    when ATTACHMENT_TYPES[:expense_item]
      '경비 항목'
    when ATTACHMENT_TYPES[:expense_sheet]
      '경비 시트'
    else
      attachment_type
    end
  end
  
  # 경비 항목용인지 확인
  def for_expense_item?
    attachment_type == ATTACHMENT_TYPES[:expense_item]
  end
  
  # 경비 시트용인지 확인
  def for_expense_sheet?
    attachment_type == ATTACHMENT_TYPES[:expense_sheet]
  end

  private

  def set_default_position
    self.position ||= self.class.maximum(:position).to_i + 1
  end
end
