class ExpenseItem < ApplicationRecord
  include CacheInvalidation
  include Approvable
  
  belongs_to :expense_sheet, counter_cache: true
  belongs_to :expense_code
  belongs_to :cost_center, optional: true
  has_many :transaction_matches, dependent: :destroy
  has_many :expense_attachments, dependent: :destroy
  
  # 결재선 관련
  belongs_to :approval_line, optional: true
  # Approvable에서 이미 정의되므로 제거
  # has_one :approval_request, dependent: :destroy
  # has_many :approval_requests, as: :approvable, dependent: :destroy


  validates :expense_date, presence: { message: "날짜 필수" }
  validates :amount, presence: { message: "금액 필수" }, numericality: { greater_than: 0, message: "0보다 커야 합니다" }
  validates :cost_center_id, presence: { message: "코스트 센터 필수" }
  validate :validate_expense_sheet_editable
  
  # custom_fields를 가상 속성으로 유지
  attr_accessor :custom_fields_cache

  before_validation :validate_with_expense_code_rules
  before_validation :validate_approval_line
  before_validation :validate_attachment_requirement
  before_validation :handle_budget_amount
  after_validation :restore_custom_fields
  before_save :generate_and_save_description
  before_save :check_budget_exceeded
  before_save :set_position
  after_save :update_expense_sheet_total
  after_destroy :update_expense_sheet_total
  after_create :create_approval_request_if_needed
  after_update :recreate_approval_if_cancelled

  scope :valid, -> { where(is_valid: true) }
  scope :invalid, -> { where(is_valid: false) }
  scope :by_date_range, ->(start_date, end_date) { where(expense_date: start_date..end_date) }
  scope :by_expense_code, ->(code_id) { where(expense_code_id: code_id) }
  scope :by_cost_center, ->(center_id) { where(cost_center_id: center_id) }
  scope :recent, -> { order(expense_date: :desc) }
  
  # Position 관련 scopes
  scope :ordered, -> { order(:position, :id) }
  scope :by_date, -> { order(:expense_date, :id) }
  scope :by_date_desc, -> { order(expense_date: :desc, id: :desc) }
  scope :by_amount, -> { order(:amount, :id) }
  scope :by_amount_desc, -> { order(amount: :desc, id: :asc) }
  scope :by_creation, -> { order(:created_at, :id) }
  scope :by_creation_desc, -> { order(created_at: :desc, id: :desc) }
  
  # ActiveStorage 최적화 scope
  scope :with_attached_file, -> { 
    includes(expense_attachments: :file_blob)
  }
  scope :by_expense_code_order, -> { 
    joins(:expense_code).order('expense_codes.display_order ASC, expense_items.id ASC') 
  }
  
  # 쿼리 최적화를 위한 추가 scope
  scope :with_associations, -> { includes(:expense_code, :cost_center, :expense_sheet) }
  scope :for_period, ->(year, month) {
    joins(:expense_sheet)
    .where(expense_sheets: { year: year, month: month })
  }
  scope :for_organization, ->(org_id) {
    joins(:expense_sheet)
    .where(expense_sheets: { organization_id: org_id })
  }
  
  # 예산 관련 스코프
  scope :budget_mode, -> { where(is_budget: true) }
  scope :actual_mode, -> { where(is_budget: false) }
  scope :budget_exceeded_items, -> { where(budget_exceeded: true) }
  scope :pending_actual_input, -> { where(is_budget: true, actual_amount: nil) }
  
  # 임시 저장 관련 스코프
  scope :drafts, -> { where(is_draft: true) }
  scope :not_drafts, -> { where(is_draft: false) }

  def formatted_amount
    "₩#{amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  def validation_status_label
    case validation_status
    when 'validated'
      '완료'
    when 'warning'
      '확인 필요'
    when 'pending'
      '미검증'
    else
      '미검증'
    end
  end
  
  def validation_badge_class
    case validation_status
    when 'validated'
      'bg-green-100 text-green-800'
    when 'warning'
      'bg-yellow-100 text-yellow-800'
    when 'failed'
      'bg-red-100 text-red-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
  
  def needs_validation?
    validation_status == 'pending' || validation_status.nil?
  end
  
  def validation_passed?
    validation_status == 'validated'
  end
  
  def validation_failed?
    validation_status == 'failed'
  end
  
  def has_validation_warning?
    validation_status == 'warning'
  end

  def validate_item
    engine = ExpenseValidation::RuleEngine.new(expense_code)
    result = engine.validate(self)
    
    self.is_valid = result.valid?
    self.validation_errors = result.errors if result.errors.any?
    
    result
  end

  def editable?
    # 경비 시트가 수정 불가능하면 false
    return false unless expense_sheet.editable?
    
    # 승인 요청이 없으면 수정 가능
    return true unless approval_request.present?
    
    # 승인이 진행 중이거나 완료된 경우 수정 불가
    return false if approval_request.status_pending? || approval_request.status_approved?
    
    # 반려된 경우만 수정 가능
    approval_request.status_rejected?
  end
  
  # 특정 조건에서만 수정 가능한지 확인
  def conditionally_editable?
    # 예산 모드이고 예산 승인이 완료되었으며 실제 금액이 없는 경우
    # 실제 집행 금액 입력만 가능
    budget_mode? && budget_approval_completed? && actual_amount.nil?
  end
  
  # 읽기 전용 모드인지 확인
  def readonly_mode?
    # 승인 진행 중이거나 승인 완료된 경우
    approval_request.present? && (approval_request.status_pending? || approval_request.status_approved?)
  end
  
  # 실제 금액 입력만 가능한 상태인지
  def actual_amount_input_only?
    budget_mode? && budget_approval_completed? && actual_amount.nil? && !readonly_mode?
  end

  def expense_month
    expense_date.strftime('%Y년 %m월')
  end

  def matches_sheet_period?
    return true unless expense_sheet && expense_date
    
    expense_date.year == expense_sheet.year && expense_date.month == expense_sheet.month
  end
  
  # 표시용 설명 (저장된 generated_description 우선 사용)
  def display_description
    # 우선순위: 1. 직접 입력된 설명, 2. 템플릿으로 생성된 설명, 3. 기본값
    description.presence || generated_description.presence || '설명 없음'
  end
  
  # 템플릿 기반 설명 실시간 생성 (미리보기용)
  def preview_generated_description
    return nil unless expense_code&.description_template.present?
    
    build_field_values_for_template
    expense_code.generate_description(@field_values)
  end
  
  # 예산 관련 메서드
  def budget_mode?
    is_budget == true
  end
  
  def actual_mode?
    !budget_mode?
  end
  
  def actual_input_pending?
    budget_mode? && actual_amount.nil?
  end
  
  def budget_approval_completed?
    budget_mode? && budget_approved_at.present?
  end
  
  def actual_approval_completed?
    actual_approved_at.present?
  end
  
  # 재승인이 필요한 상태인지 확인
  def needs_reapproval?
    budget_mode? && budget_exceeded? && approval_request&.status == 'pending' && budget_approved_at.present?
  end
  
  def calculate_budget_usage_rate
    return nil unless budget_amount.present? && budget_amount > 0
    return nil unless actual_amount.present?
    
    ((actual_amount / budget_amount) * 100).round(2)
  end
  
  def budget_status
    return 'N/A' unless budget_mode?
    
    if actual_amount.nil?
      '집행 대기'
    elsif budget_exceeded?
      '예산 초과'
    elsif actual_amount <= budget_amount
      '정상 집행'
    end
  end
  
  def check_budget_exceeded
    return false unless budget_mode?
    return false unless budget_amount.present? && actual_amount.present?
    
    self.budget_exceeded = actual_amount > budget_amount
  end
  
  def effective_amount
    # 승인 프로세스에 사용할 금액 반환
    if budget_mode?
      # 예산 모드에서는 budget_amount를 우선 사용
      budget_amount || amount
    else
      # 일반 모드에서는 actual_amount를 우선 사용, 없으면 amount
      actual_amount || amount
    end
  end
  
  def requires_reapproval?
    budget_mode? && budget_exceeded? && excess_reason.present?
  end
  
  # ===== Approvable 인터페이스 구현 =====
  
  def display_title
    # 경비 날짜 (MM/DD) - 경비 코드명 - 금액 형식
    date_str = expense_date.strftime('%m/%d') if expense_date
    "#{date_str} - #{expense_code.name} - #{formatted_amount}"
  end
  
  def display_description
    # 기존 설명과 사용자명 표시
    base_description = read_attribute(:display_description).presence || description || generated_description || "경비 항목"
    user_name = expense_sheet&.user&.name if expense_sheet
    user_name ? "#{base_description} (#{user_name})" : base_description
  end
  
  def display_amount
    formatted_amount
  end
  
  # 임시 저장 관련 메서드
  def save_as_draft(params)
    begin
      # 동일한 expense_sheet의 기존 임시 저장 삭제
      if expense_sheet_id.present?
        ExpenseItem.where(
          expense_sheet_id: expense_sheet_id,
          is_draft: true
        ).where.not(id: id).destroy_all
      end
      
      self.is_draft = true
      self.draft_data = params
      self.last_saved_at = Time.current
      
      # NOT NULL 필드에 기본값 설정 (draft 모드일 때만)
      self.expense_code_id ||= ExpenseCode.first&.id || 1  # 임시로 첫 번째 코드 사용
      self.expense_date ||= Date.current
      self.amount ||= 0
      self.description ||= "임시 저장"
      
      # 검증 없이 저장 (임시 저장은 미완성 상태 허용)
      save(validate: false)
    rescue => e
      Rails.logger.error "임시 저장 실패: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end
  
  def restore_from_draft
    return unless is_draft? && draft_data.present?
    
    # draft_data가 문자열인 경우 JSON 파싱
    data = draft_data.is_a?(String) ? JSON.parse(draft_data) : draft_data
    
    # expense_item 네임스페이스 처리
    if data['expense_item'].present?
      data = data['expense_item']
    end
    
    data.each do |key, value|
      if key == 'custom_fields' && value.is_a?(Hash)
        # custom_fields는 직접 할당
        self.custom_fields = value
      elsif respond_to?("#{key}=")
        send("#{key}=", value)
      end
    end
  end
  
  # draft_data로부터 데이터 복원 (새 객체용)
  def restore_from_draft_data(data)
    return unless data.present?
    
    # draft_data가 문자열인 경우 JSON 파싱
    data = data.is_a?(String) ? JSON.parse(data) : data
    
    # attachment_ids 백업
    attachment_ids = data['attachment_ids'] || data[:attachment_ids]
    
    # expense_item 네임스페이스 처리
    if data['expense_item'].present?
      data = data['expense_item']
    end
    
    data.each do |key, value|
      if key == 'custom_fields' && value.is_a?(Hash)
        # custom_fields는 직접 할당
        self.custom_fields = value
      elsif key == 'attachment_ids'
        # attachment_ids는 별도로 처리 (아래에서)
        next
      elsif respond_to?("#{key}=") && key != 'id'  # id는 제외
        send("#{key}=", value)
      end
    end
    
    # 첨부파일 연결 복원
    if attachment_ids.present?
      @restored_attachment_ids = attachment_ids
    end
  end
  
  # 복원된 첨부파일 ID 접근자
  attr_accessor :restored_attachment_ids
  
  def finalize_draft
    self.is_draft = false
    self.draft_data = {}
    save
  end
  
  def draft_age_in_minutes
    return nil unless last_saved_at?
    ((Time.current - last_saved_at) / 1.minute).round
  end
  
  def draft_status_message
    return nil unless is_draft?
    
    age = draft_age_in_minutes
    return "방금 저장됨" if age.nil? || age < 1
    return "#{age}분 전 저장됨" if age < 60
    return "#{age / 60}시간 전 저장됨" if age < 1440
    "#{age / 1440}일 전 저장됨"
  end
  
  
  def generate_and_save_description
    # 템플릿이 있으면 템플릿 기반 생성
    if expense_code&.description_template.present?
      build_field_values_for_template
      self.generated_description = expense_code.generate_description(@field_values)
      # description 필드도 설정 (readonly지만 저장 필요)
      self.description = self.generated_description if self.generated_description.present?
    else
      # 템플릿이 없는 경비 코드도 기본 설명 자동 생성
      build_field_values_for_template
      
      # 기본 템플릿으로 설명 생성
      desc_parts = []
      desc_parts << expense_code.name if expense_code.present?
      desc_parts << expense_date&.strftime('%Y-%m-%d')
      desc_parts << formatted_amount if amount.present?
      
      # custom_fields 값 추가
      if custom_fields.present?
        custom_fields.each do |key, value|
          next if value.blank?
          desc_parts << value
        end
      end
      
      # 기본 설명 생성
      generated_desc = desc_parts.compact.join(' - ')
      self.generated_description = generated_desc
      self.description = generated_desc if generated_desc.present?
    end
    
    # description 필수 체크를 위한 기본값 설정
    self.description = "경비 항목" if self.description.blank?
  end
  
  def build_field_values_for_template
    @field_values = {
      'amount' => formatted_amount,
      'expense_date' => expense_date&.strftime('%Y-%m-%d'),
      'cost_center' => cost_center&.name,
      'vendor_name' => vendor_name,
      'receipt_number' => receipt_number,
      # 한글 레이블도 추가
      '금액' => formatted_amount,
      '경비일자' => expense_date&.strftime('%Y-%m-%d'),
      '코스트센터' => cost_center&.name,
      '거래처명' => vendor_name,
      '영수증번호' => receipt_number
    }
    
    # custom_fields를 field_values에 추가
    if custom_fields.present? && expense_code.validation_rules['required_fields'].present?
      expense_code.validation_rules['required_fields'].each do |field_key, field_config|
        if custom_fields[field_key].present?
          # 필드 키와 레이블 둘 다 사용 가능하도록 추가
          @field_values[field_key] = custom_fields[field_key]
          
          # 새로운 구조인 경우 레이블도 추가
          if field_config.is_a?(Hash) && field_config['label'].present?
            @field_values[field_config['label']] = custom_fields[field_key]
          end
        end
      end
    end
    
    @field_values
  end
  
  def validate_with_expense_code_rules
    # validation 전에 custom_fields 백업
    self.custom_fields_cache = self.custom_fields
    
    return unless expense_code.present?
    
    # 새로운 경비 항목이고 날짜가 시트 기간과 맞지 않으면, 적절한 시트로 변경
    if new_record? && expense_date.present? && expense_sheet.present?
      unless matches_sheet_period?
        # 날짜에 맞는 시트 찾기 또는 생성
        target_sheet = ExpenseSheet.find_or_create_by(
          user: expense_sheet.user,
          year: expense_date.year,
          month: expense_date.month
        ) do |sheet|
          sheet.organization = expense_sheet.user.organization
          sheet.status = 'draft'
        end
        
        # 시트 변경
        self.expense_sheet = target_sheet
      end
    end
    
    result = validate_item
    unless result.valid?
      result.errors.each do |error|
        # 한도 초과 에러는 amount 필드에 추가
        if error.include?("한도 초과")
          errors.add(:amount, error)
        else
          # 필수 필드 에러는 custom_fields에 추가
          errors.add(:base, error)
        end
      end
    end
  end
  
  def restore_custom_fields
    # validation 실패 시 custom_fields 복원
    if errors.any? && self.custom_fields_cache.present?
      self.custom_fields = self.custom_fields_cache
    end
  end
  
  def validate_approval_line
    # ExpenseSheet에 결재선이 있는 경우 일치하는지 확인
    if expense_sheet&.approval_line_id.present? && approval_line_id.present? && expense_sheet.approval_line_id != approval_line_id
      errors.add(:approval_line, "경비 시트의 결재선과 일치해야 합니다")
      return
    end
    
    # 승인 규칙이 트리거되는지 확인
    if expense_code.present?
      triggered_rules = expense_code.expense_code_approval_rules
                                  .active
                                  .ordered
                                  .select { |rule| rule.evaluate(self) }
      
      # 사용자보다 높은 권한의 승인이 필요한 규칙만 남김
      # 예: 사용자가 보직자인 경우, 보직자 승인은 불필요하지만 조직리더/조직총괄/CEO 승인은 필요
      user = expense_sheet&.user
      if user
        user_max_priority = user.approver_groups.maximum(:priority) || 0
        triggered_rules = triggered_rules.select { |rule| rule.approver_group.priority > user_max_priority }
      end
      
      # 승인 규칙이 트리거되었는데 결재선이 없는 경우
      if triggered_rules.any? && approval_line_id.blank?
        # 필요한 승인자 그룹 정보 수집
        required_groups = triggered_rules.map(&:approver_group).uniq
        group_names = required_groups.map(&:name).join(', ')
        
        errors.add(:approval_line, "승인이 필요합니다. 필요한 승인자: #{group_names}")
        return
      end
    end
    
    # 결재선이 지정된 경우 검증
    return unless approval_line_id.present?
    
    # 결재선 검증 서비스 호출
    validator = ExpenseValidation::ApprovalLineValidator.new(self)
    unless validator.validate
      validator.error_messages.each do |message|
        errors.add(:approval_line, message)
      end
    end
  end

  def update_expense_sheet_total
    expense_sheet.calculate_total_amount
    expense_sheet.save(validate: false)
  end

  def handle_budget_amount
    # 예산 모드일 때 budget_amount를 amount에도 설정
    if budget_mode? && budget_amount.present?
      self.amount = budget_amount
    elsif !budget_mode? && actual_amount.present?
      self.amount = actual_amount
    end
  end
  
  def expense_data_for_validation
    {
      amount: effective_amount,  # 예산/실집행 모드에 따라 적절한 금액 사용
      expense_date: expense_date,
      description: description,
      custom_fields: custom_fields || {},
      cost_center_id: cost_center_id,
      vendor_name: vendor_name,
      receipt_number: receipt_number
    }
  end
  
  # 승인 요청 생성/재생성 (public 메서드)
  def create_approval_request_if_needed
    # 결재선이 선택된 경우에만 ApprovalRequest 생성
    return unless approval_line_id.present?
    
    # 기존 ApprovalRequest가 있는 경우
    if approval_request.present?
      # 취소된 상태면 새로운 ApprovalRequest 생성
      if approval_request.status_cancelled?
        Rails.logger.info "ExpenseItem ##{id}: 취소된 승인 요청이 있으므로 새로운 승인 요청을 생성합니다."
        # 기존 취소된 요청은 그대로 두고 새로운 요청 생성
        # (기존 요청 삭제하면 이력이 사라짐)
        approval_request.destroy
        ApprovalRequest.create_with_approval_line(self, approval_line)
      else
        # 진행 중이거나 완료된 경우는 생성하지 않음
        Rails.logger.info "ExpenseItem ##{id}: 이미 진행 중인 승인 요청이 있습니다. (status: #{approval_request.status})"
        return
      end
    else
      # ApprovalRequest가 없으면 새로 생성
      ApprovalRequest.create_with_approval_line(self, approval_line)
    end
  end
  
  # 위치 업데이트 메서드
  def self.update_positions(sheet_id, item_ids)
    transaction do
      item_ids.each_with_index do |id, index|
        where(id: id, expense_sheet_id: sheet_id).update_all(position: index + 1)
      end
    end
  end
  
  private
  
  def set_position
    if position.blank?
      max_position = expense_sheet.expense_items.maximum(:position) || 0
      self.position = max_position + 1
    end
  end
  
  # 취소된 승인 요청 재생성
  def recreate_approval_if_cancelled
    # 승인 라인이 있고, 승인 요청이 취소 상태인 경우
    if approval_line_id.present? && approval_request&.status_cancelled?
      Rails.logger.info "ExpenseItem ##{id}: 취소된 승인 요청 재생성 시작"
      
      # 기존 취소된 요청 삭제
      approval_request.destroy
      
      # 새로운 승인 요청 생성
      new_request = ApprovalRequest.create_with_approval_line(self, approval_line)
      
      Rails.logger.info "ExpenseItem ##{id}: 새 승인 요청 생성됨 (ID: #{new_request.id})"
    end
  end
  
  def validate_attachment_requirement
    # 시드 데이터 로드 중에는 검증 무시
    return if ENV['SEEDING'] == 'true'
    
    # 경비 코드가 첨부파일을 필수로 요구하는지 확인
    return unless expense_code.present?
    return unless expense_code.attachment_required?
    
    # 연결된 첨부파일 체크 (build된 것 포함)
    has_attachments = expense_attachments.any? || expense_attachments.length > 0
    
    # 예산 모드이지만 실제 집행 금액이 입력된 경우 (실제 집행 단계)
    if budget_mode? && actual_amount.present?
      # 실제 집행 시에는 첨부파일 필수
      unless has_attachments
        errors.add(:base, "실제 집행 시 증빙 서류(#{expense_code.name})는 필수입니다.")
      end
    # 신규 예산 모드 생성 시에는 첨부파일 검증 무시
    elsif budget_mode? && !persisted?
      return
    # 일반 모드 또는 예산 모드가 아닌 경우
    elsif !budget_mode?
      unless has_attachments
        errors.add(:base, "이 경비 코드(#{expense_code.name})는 첨부파일이 필수입니다.")
      end
    end
  end
  
  def validate_expense_sheet_editable
    # 날짜가 없으면 검증 불가
    return unless expense_date.present?
    
    # 사용자 정보가 없으면 검증 불가 (expense_sheet을 통해 user 접근)
    return unless expense_sheet.present?
    
    # 날짜가 변경된 경우에만 검증
    if expense_date_changed?
      # 해당 날짜의 경비 시트 확인
      target_sheet = ExpenseSheet.find_by(
        user: expense_sheet.user,
        year: expense_date.year,
        month: expense_date.month
      )
      
      # 대상 시트가 있고 편집 불가능한 상태면 에러
      if target_sheet && target_sheet != expense_sheet && !target_sheet.editable?
        errors.add(:expense_date, "#{expense_date.year}년 #{expense_date.month}월 시트는 이미 제출되었습니다. 다른 날짜를 선택해주세요.")
      end
    end
  end
  
end