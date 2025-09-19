class RequestTemplate < ApplicationRecord
  # 관계 설정
  belongs_to :request_category
  has_many :request_template_fields, dependent: :destroy
  has_many :request_forms, dependent: :restrict_with_error
  has_many :request_template_approval_rules, dependent: :destroy
  
  # Serialize JSON fields
  serialize :fields, coder: JSON
  
  # Set default values
  after_initialize :set_defaults
  
  # Nested attributes
  accepts_nested_attributes_for :request_template_fields, allow_destroy: true
  accepts_nested_attributes_for :request_template_approval_rules, allow_destroy: true
  
  # 검증 규칙
  validates :name, presence: true, uniqueness: { scope: :request_category_id }
  validates :code, presence: true, uniqueness: true, format: { with: /\A[A-Z]{2,}-\d{3}\z/, message: "형식이 잘못되었습니다 (예: SEC-001)" }
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }
  validates :version, numericality: { greater_than: 0 }
  validates :is_active, inclusion: { in: [true, false] }
  validates :attachment_required, inclusion: { in: [true, false] }
  validates :auto_numbering, inclusion: { in: [true, false] }
  
  # 콜백
  before_validation :generate_code, on: :create
  
  # 스코프
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:display_order, :id) }
  scope :for_category, ->(category) { where(request_category: category) }
  
  # 코드 자동 생성
  def generate_code
    return if code.present?
    
    if request_category
      # 한글을 처리하기 위해 영문 약어 매핑 사용
      prefix = case request_category.name
      when '정보보안'
        'SEC'
      when '인사총무'
        'HRD'
      when '재무회계'
        'FIN'
      when '구매'
        'PRC'
      else
        # 기본값: 첫 3글자를 영문으로 변환 시도
        request_category.name.gsub(/[^A-Za-z]/, '')[0..2].upcase || 'GEN'
      end
      
      # 최소 2자 이상 보장
      prefix = 'GN' if prefix.length < 2
      
      last_code = RequestTemplate.where("code LIKE ?", "#{prefix}-%").order(:code).last
      
      if last_code
        number = last_code.code.split('-').last.to_i + 1
      else
        number = 1
      end
      
      self.code = "#{prefix}-#{number.to_s.rjust(3, '0')}"
    end
  end
  
  # 필수 필드 수
  def required_fields_count
    request_template_fields.where(is_required: true).count
  end
  
  # 선택 필드 수
  def optional_fields_count
    request_template_fields.where(is_required: false).count
  end
  
  # 템플릿 복사
  def duplicate(new_name = nil)
    new_template = self.dup
    new_template.name = new_name || "#{name} (복사본)"
    new_template.code = nil # 자동 생성되도록
    
    if new_template.save
      request_template_fields.each do |field|
        new_field = field.dup
        new_field.request_template = new_template
        new_field.save
      end
      
      request_template_approval_rules.each do |rule|
        new_rule = rule.dup
        new_rule.request_template = new_template
        new_rule.save
      end
    end
    
    new_template
  end
  
  # 표시용 전체 이름
  def full_display_name
    "[#{request_category.name}] #{name}"
  end
  
  private
  
  def set_defaults
    self.fields ||= []
  end
end
