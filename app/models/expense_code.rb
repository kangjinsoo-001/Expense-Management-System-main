class ExpenseCode < ApplicationRecord
  store_accessor :validation_rules, :required_fields, :auto_approval_conditions, :custom_validators
  
  # 필드 타입 정의
  FIELD_TYPES = {
    text: '텍스트',
    number: '숫자',
    participants: '구성원',
    organization: '조직',
    select: '선택지'
  }.freeze
  
  # 기본 필드 정의
  DEFAULT_FIELDS = {
    'description' => { type: 'text', label: '상세설명', required: true },
    'amount' => { type: 'amount', label: '금액', required: true },
    'expense_date' => { type: 'date', label: '사용일자', required: true }
  }.freeze
  
  belongs_to :organization, optional: true
  has_many :expense_items, dependent: :restrict_with_error
  belongs_to :parent_code, class_name: 'ExpenseCode', optional: true
  has_many :versions, class_name: 'ExpenseCode', foreign_key: 'parent_code_id'
  has_many :expense_code_approval_rules, dependent: :destroy
  # Polymorphic 관계 추가
  has_many :approval_requests, as: :approvable, dependent: :destroy
  
  # Nested attributes for approval rules
  accepts_nested_attributes_for :expense_code_approval_rules, allow_destroy: true
  
  validates :code, presence: true
  validates :name, presence: true
  
  # 정렬 기본값
  default_scope { order(:display_order, :id) }
  validates :version, presence: true, numericality: { greater_than: 0 }
  validate :ensure_unique_code_version
  validate :validate_description_template
  validate :validate_limit_amount_formula
  
  scope :active, -> { where(active: true) }
  scope :current, -> { where(is_current: true) }
  scope :with_limit, -> { where.not(limit_amount: nil) }
  scope :for_organization, ->(org) { where(organization: org).or(where(organization: nil)) }
  scope :effective_on, ->(date) { where('effective_from <= ? AND (effective_to IS NULL OR effective_to >= ?)', date, date) }
  
  # 새 버전 생성 콜백
  before_create :set_effective_dates, if: :new_version?
  after_create :update_previous_version, if: :new_version?
  
  def validate_expense_item(item)
    engine = ExpenseValidation::RuleEngine.new(self)
    result = engine.validate(item)
    result.errors
  end
  
  def auto_approvable?(item)
    engine = ExpenseValidation::RuleEngine.new(self)
    engine.auto_approvable?(item)
  end
  
  def validation_engine
    @validation_engine ||= ExpenseValidation::RuleEngine.new(self)
  end

  def name_with_code
    "#{code} - #{name}"
  end
  
  def display_name
    name_with_code
  end
  
  # 한도 금액 계산 (수식 파싱)
  def calculate_limit_amount(expense_item = nil)
    return nil if limit_amount.blank?
    
    # 단순 숫자인 경우
    if limit_amount.match?(/\A\d+\z/)
      return limit_amount.to_i
    end
    
    # 수식인 경우 파싱
    return parse_limit_formula(limit_amount, expense_item)
  end
  
  # 한도가 수식인지 확인
  def has_formula_limit?
    limit_amount.present? && !limit_amount.match?(/\A\d+\z/)
  end
  
  # 표시용 한도 설명
  def limit_amount_display
    return nil if limit_amount.blank?
    
    if has_formula_limit?
      # 수식을 사람이 읽기 쉽게 변환
      formula = limit_amount.dup
      
      # 필드명을 레이블로 변환
      if required_fields.is_a?(Hash)
        required_fields.each do |key, field_config|
          if field_config.is_a?(Hash) && field_config['label']
            formula.gsub!("##{key}", field_config['label'])
          end
        end
      end
      
      formula
    else
      # 단순 숫자인 경우 통화 형식으로
      "₩#{limit_amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end
  end
  
  # 템플릿 기반 설명 생성
  def generate_description(field_values = {})
    return nil if description_template.blank?
    
    # 템플릿 파싱 및 필드 값 치환
    parsed_template = description_template.dup
    
    # 레이블 -> 필드 키 매핑 생성
    label_to_key_map = {}
    if required_fields.is_a?(Hash)
      required_fields.each do |key, field_config|
        if field_config.is_a?(Hash) && field_config['label']
          label_to_key_map[field_config['label']] = key
        end
      end
    end
    
    # #필드명 형태의 플레이스홀더를 실제 값으로 치환
    field_values.each do |field_name, value|
      next if value.blank? # 빈 값은 건너뛰기
      
      # 필드 키로 직접 치환
      placeholder = "##{field_name}"
      parsed_template.gsub!(placeholder, value.to_s)
      
      # 레이블로도 치환 시도
      label = required_fields.dig(field_name, 'label') if required_fields.is_a?(Hash)
      if label
        label_placeholder = "##{label}"
        parsed_template.gsub!(label_placeholder, value.to_s)
      end
    end
    
    # 레이블로 매핑된 필드도 치환
    label_to_key_map.each do |label, key|
      if field_values[key].present?
        label_placeholder = "##{label}"
        parsed_template.gsub!(label_placeholder, field_values[key].to_s)
      end
    end
    
    # 치환되지 않은 플레이스홀더 제거
    # 예: "#사유" → "" (빈 문자열)
    parsed_template.gsub!(/#[\w가-힣]+/, '')
    
    # 연속된 공백 정리, 앞뒤 공백 제거
    parsed_template = parsed_template.strip
                                     .gsub(/\s+/, ' ')
                                     .gsub(/\(\s*\)/, '') # 빈 괄호 제거
    
    parsed_template
  end
  
  # 템플릿에서 필요한 필드 목록 추출
  def template_fields
    return [] if description_template.blank?
    
    # #필드명 형태의 플레이스홀더 추출
    # #으로 시작하고 다음 #이 나오거나 특수문자(괄호, 쉼표 등)가 나올 때까지의 내용 추출
    fields = []
    # 패턴: #으로 시작하고, 다음 구분자까지의 모든 문자 매칭
    # 구분자: 공백, 괄호, 쉼표, 화살표, 다음 #, 문자열 끝
    description_template.scan(/#([^#\s\(\),→]+)/) do |match|
      field_name = match[0]
      # 마지막에 있는 특수문자 제거 (예: 언더스코어, 하이픈 등)
      field_name = field_name.gsub(/[_\-→]$/, '')
      fields << field_name unless field_name.empty?
    end
    fields.uniq
  end
  
  # 템플릿이 유효한지 검증
  def template_valid?
    return true if description_template.blank?
    
    # 템플릿에 사용된 필드가 field_definitions에 정의되어 있는지 확인
    template_fields.all? do |field|
      field_definitions.key?(field) || DEFAULT_FIELDS.key?(field)
    end
  end
  
  # 새 버전 생성
  def create_new_version!(changes = {})
    new_version = self.class.new(
      attributes.except('id', 'created_at', 'updated_at').merge(changes)
    )
    new_version.parent_code_id = parent_code_id || id
    
    # 동일한 코드의 모든 버전을 찾아서 최대 버전 계산
    max_version = self.class.where(code: code).maximum(:version) || 0
    new_version.version = max_version + 1
    
    new_version.is_current = true
    new_version.save!
    
    # 승인 규칙 복사
    expense_code_approval_rules.each do |rule|
      new_version.expense_code_approval_rules.create!(
        condition: rule.condition,
        approver_group_id: rule.approver_group_id,
        order: rule.order,
        is_active: rule.is_active
      )
    end
    
    new_version
  end
  
  # 특정 날짜에 유효한 버전 찾기
  def self.find_effective(code, date = Date.current)
    where(code: code)
      .effective_on(date)
      .order(version: :desc)
      .first
  end
  
  # 필수 필드 변경 시 템플릿과 한도 업데이트
  def update_template_and_limit_on_field_change!(old_fields, new_fields)
    return unless old_fields.is_a?(Hash) && new_fields.is_a?(Hash)
    
    # 변경된 필드 찾기 (키 이름이나 레이블이 변경된 경우)
    field_changes = {}
    
    # 키 이름 변경 확인
    old_fields.each do |old_key, old_config|
      next unless old_config.is_a?(Hash)
      old_label = old_config['label'] || old_key
      
      # 새 필드에서 같은 키가 없는 경우
      unless new_fields.key?(old_key)
        # 같은 타입과 순서를 가진 필드 찾기
        new_key = new_fields.find do |key, config|
          config.is_a?(Hash) && 
          config['type'] == old_config['type'] && 
          config['order'] == old_config['order']
        end&.first
        
        if new_key
          new_label = new_fields[new_key]['label'] || new_key
          field_changes[old_key] = new_key
          field_changes[old_label] = new_label if old_label != old_key
        end
      else
        # 키는 같지만 레이블이 변경된 경우
        new_config = new_fields[old_key]
        if new_config.is_a?(Hash)
          new_label = new_config['label'] || old_key
          if old_label != new_label
            field_changes[old_label] = new_label
          end
        end
      end
    end
    
    return if field_changes.empty?
    
    # 설명 템플릿 업데이트
    if description_template.present?
      updated_template = description_template.dup
      field_changes.each do |old_name, new_name|
        updated_template.gsub!("##{old_name}", "##{new_name}")
      end
      self.description_template = updated_template
    end
    
    # 한도 수식 업데이트
    if limit_amount.present? && has_formula_limit?
      updated_limit = limit_amount.dup
      field_changes.each do |old_name, new_name|
        updated_limit.gsub!("##{old_name}", "##{new_name}")
      end
      self.limit_amount = updated_limit
    end
  end
  
  private
  
  def number_to_currency(amount)
    return "₩0" if amount.nil? || amount == 0
    
    # 천 단위 구분 쉼표 추가
    formatted = amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    "₩#{formatted}"
  end
  
  # 수식 파싱 및 계산
  def parse_limit_formula(formula, expense_item = nil)
    return nil if formula.blank?
    
    # 수식 복사본으로 작업
    parsed_formula = formula.dup
    
    # expense_item이 없으면 기본값 계산 불가
    return nil if expense_item.nil? && formula.include?('#')
    
    # 레이블 -> 필드 키 매핑 생성
    label_to_key_map = {}
    if required_fields.is_a?(Hash)
      required_fields.each do |key, field_config|
        if field_config.is_a?(Hash) && field_config['label']
          label_to_key_map[field_config['label']] = key
        end
      end
    end
    
    # 수식에서 레이블을 키로 변환
    label_to_key_map.each do |label, key|
      parsed_formula.gsub!("##{label}", "##{key}")
    end
    
    # 필드 값 치환
    if expense_item && expense_item.custom_fields.present?
      expense_item.custom_fields.each do |field_key, field_value|
        # participants 타입의 경우 쉼표로 구분된 인원수 계산
        field_type = required_fields.dig(field_key, 'type')
        
        if field_type == 'participants'
          count = field_value.to_s.split(',').map(&:strip).reject(&:empty?).size
          parsed_formula.gsub!("##{field_key}", count.to_s)
        elsif field_type == 'number' || field_value.to_s.match?(/\A\d+\z/)
          # number 타입이거나 숫자인 경우만 치환
          parsed_formula.gsub!("##{field_key}", field_value.to_s)
        end
      end
    end
    
    # 남은 플레이스홀더가 있으면 계산 불가
    return nil if parsed_formula.include?('#')
    
    # 안전한 수식 평가 (숫자와 기본 연산자만 허용)
    if parsed_formula.match?(/\A[\d\s\+\-\*\/\(\)]+\z/)
      begin
        eval(parsed_formula).to_i
      rescue
        nil
      end
    else
      nil
    end
  end
  
  # 한도 수식 검증
  def validate_limit_amount_formula
    return if limit_amount.blank?
    
    # 단순 숫자인 경우 유효
    if limit_amount.match?(/\A\d+\z/)
      return
    end
    
    # 허용된 문자만 포함하는지 확인 (숫자, 연산자, 공백, #, 영문자)
    unless limit_amount.match?(/\A[\d\s\+\-\*\/\(\)#a-zA-Z가-힣_]+\z/)
      errors.add(:limit_amount, "올바른 수식이 아닙니다. 숫자와 연산자(+, -, *, /, 괄호), 필드명(#필드명)만 사용할 수 있습니다.")
      return
    end
    
    # 필드명 추출 및 검증
    field_names = limit_amount.scan(/#([a-zA-Z가-힣_]+)/).flatten
    if field_names.any?
      # required_fields 확인
      valid_field_keys = required_fields.is_a?(Hash) ? required_fields.keys : []
      
      # 레이블로도 매핑 가능하도록 레이블 목록 생성
      required_field_labels = []
      label_to_key_map = {}
      if required_fields.is_a?(Hash)
        required_fields.each do |key, field_config|
          if field_config.is_a?(Hash) && field_config['label']
            required_field_labels << field_config['label']
            label_to_key_map[field_config['label']] = key
          end
        end
      end
      
      # 필드 키와 레이블 모두 포함한 유효한 필드 목록
      valid_fields = valid_field_keys + required_field_labels
      
      # 정의되지 않은 필드 찾기
      undefined_fields = field_names - valid_fields
      
      if undefined_fields.any?
        errors.add(:limit_amount, "다음 필드가 정의되어 있지 않습니다: #{undefined_fields.join(', ')}")
        return
      end
      
      # 숫자가 아닌 필드 타입 확인 (레이블을 키로 변환하여 확인)
      non_numeric_fields = field_names.select do |field_name|
        # 필드명이 레이블인 경우 키로 변환
        actual_key = label_to_key_map[field_name] || field_name
        
        if valid_field_keys.include?(actual_key)
          field_type = required_fields.dig(actual_key, 'type')
          field_type.present? && !['number', 'participants'].include?(field_type)
        else
          false
        end
      end
      
      if non_numeric_fields.any?
        errors.add(:limit_amount, "다음 필드는 숫자 계산에 사용할 수 없습니다: #{non_numeric_fields.join(', ')}")
      end
    end
  end
  
  def ensure_unique_code_version
    # 자기 자신은 제외하고 검사
    existing = self.class.where(code: code, version: version)
    existing = existing.where.not(id: id) if persisted?
    
    if existing.exists?
      errors.add(:base, "이미 존재하는 버전입니다")
    end
  end
  
  def validate_description_template
    return true if description_template.blank?
    
    # 템플릿에서 사용된 필드 추출
    template_field_names = template_fields
    
    # required_fields 가져오기
    required_field_keys = required_fields.is_a?(Hash) ? required_fields.keys : []
    
    # 레이블로도 매핑 가능하도록 레이블 목록 생성
    required_field_labels = []
    if required_fields.is_a?(Hash)
      required_fields.each do |key, field_config|
        required_field_labels << field_config['label'] if field_config.is_a?(Hash) && field_config['label']
      end
    end
    
    # 템플릿에 사용된 필드가 required_fields의 키 또는 레이블에 정의되어 있는지 확인
    valid_fields = required_field_keys + required_field_labels + ['amount', 'expense_date', 'cost_center']
    undefined_fields = template_field_names - valid_fields
    
    if undefined_fields.any?
      errors.add(:description_template, "설명 템플릿의 다음 필드가 필수 필드에 정의되어 있지 않습니다: #{undefined_fields.join(', ')}")
    end
  end
  
  def new_version?
    parent_code_id.present? || versions.any?
  end
  
  def set_effective_dates
    self.effective_from ||= Date.current
  end
  
  def update_previous_version
    # 이전 버전들의 is_current를 false로 설정
    if parent_code_id
      ExpenseCode.where(code: code)
                 .where.not(id: id)
                 .update_all(is_current: false)
      
      # 직전 버전의 effective_to 설정
      previous = ExpenseCode.where(code: code)
                           .where.not(id: id)
                           .order(version: :desc)
                           .first
      previous&.update_columns(effective_to: effective_from - 1.day)
    end
  end
end
