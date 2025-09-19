class RequestTemplateField < ApplicationRecord
  # 관계 설정
  belongs_to :request_template
  
  # 필드 타입 정의
  FIELD_TYPES = {
    'text' => '한줄 텍스트',
    'textarea' => '여러줄 텍스트',
    'number' => '숫자',
    'date' => '날짜',
    'datetime' => '날짜시간',
    'select' => '드롭다운',
    'checkbox' => '체크박스',
    'radio' => '라디오버튼',
    'file' => '파일첨부',
    'email' => '이메일',
    'phone' => '전화번호'
  }.freeze
  
  DISPLAY_WIDTHS = %w[full half third].freeze
  
  # JSON 필드 접근자 (SQLite text 필드를 JSON처럼 사용)
  serialize :field_options, coder: JSON
  serialize :validation_rules, coder: JSON
  
  # 검증 규칙
  validates :field_key, presence: true, uniqueness: { scope: :request_template_id }, format: { with: /\A[a-z_]+\z/, message: "소문자와 언더스코어만 사용 가능합니다" }
  validates :field_label, presence: true
  validates :field_type, presence: true, inclusion: { in: FIELD_TYPES.keys }
  validates :display_order, numericality: { greater_than_or_equal_to: 0 }
  validates :display_width, inclusion: { in: DISPLAY_WIDTHS }
  validates :is_required, inclusion: { in: [true, false] }
  
  # 콜백
  before_validation :set_defaults
  
  # 스코프
  scope :required, -> { where(is_required: true) }
  scope :optional, -> { where(is_required: false) }
  scope :ordered, -> { order(:display_order, :id) }
  
  # 필드 타입 한글명
  def field_type_name
    FIELD_TYPES[field_type]
  end
  
  # 선택지가 있는 필드 타입인지
  def has_options?
    %w[select radio checkbox].include?(field_type)
  end
  
  # 파일 필드인지
  def is_file_field?
    field_type == 'file'
  end
  
  # 필드 옵션 가져오기 (안전하게)
  def get_field_options
    field_options || {}
  end
  
  # 검증 규칙 가져오기 (안전하게)
  def get_validation_rules
    validation_rules || {}
  end
  
  # 선택지 목록 가져오기
  def option_values
    return [] unless has_options?
    get_field_options['options'] || []
  end
  
  # 기본값 가져오기
  def default_value
    get_field_options['default']
  end
  
  # CSS 클래스 (너비)
  def css_width_class
    case display_width
    when 'half'
      'col-md-6'
    when 'third'
      'col-md-4'
    else
      'col-md-12'
    end
  end
  
  private
  
  def set_defaults
    self.display_width ||= 'full'
    self.display_order ||= 0
    self.is_required ||= false
  end
end