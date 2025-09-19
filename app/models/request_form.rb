class RequestForm < ApplicationRecord
  include Approvable
  
  # 관계 설정
  belongs_to :request_template
  belongs_to :request_category
  belongs_to :user
  belongs_to :organization
  belongs_to :approval_line, optional: true
  has_many :request_form_attachments, dependent: :destroy
  
  # Approvable에서 이미 정의되므로 제거
  # has_many :approval_requests, as: :approvable, dependent: :destroy
  # has_one :approval_request, -> { order(created_at: :desc) }, as: :approvable, dependent: :destroy
  
  # JSON 필드 (SQLite text 필드를 JSON처럼 사용)
  serialize :form_data, coder: JSON
  serialize :draft_data, coder: JSON
  
  # 상태 정의
  STATUSES = {
    'draft' => '임시저장',
    'submitted' => '제출됨',
    'pending' => '승인대기',
    'approved' => '승인완료',
    'rejected' => '반려됨',
    'cancelled' => '취소됨'
  }.freeze
  
  # 검증 규칙
  validates :status, inclusion: { in: STATUSES.keys }
  validates :request_template, presence: true
  validates :user, presence: true
  validates :organization, presence: true
  validate :validate_required_fields, if: :submitted_or_pending?
  validate :validate_approval_line, if: :needs_approval?
  
  # 콜백
  before_validation :set_title
  before_validation :generate_request_number, on: :create
  before_create :set_initial_status
  after_update :create_approval_request_if_needed
  # Approvable에서 이미 정의되므로 제거
  # before_destroy :check_can_be_deleted
  
  # 스코프
  scope :drafts, -> { where(is_draft: true) }
  scope :not_drafts, -> { where(is_draft: false) }
  scope :submitted, -> { where(status: 'submitted') }
  scope :pending_approval, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  
  # 상태 확인 메서드
  def draft?
    status == 'draft'
  end
  
  def submitted?
    status == 'submitted'
  end
  
  def pending?
    status == 'pending'
  end
  
  def approved?
    status == 'approved'
  end
  
  def rejected?
    status == 'rejected'
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  def submitted_or_pending?
    submitted? || pending?
  end
  
  def needs_approval?
    submitted? || pending?
  end
  
  # 상태 변경 메서드
  def submit!
    return false if !draft? || !valid?
    
    transaction do
      self.status = 'submitted'
      self.submitted_at = Time.current
      self.is_draft = false
      save!
      
      # 승인이 필요한 경우
      if approval_line.present?
        self.status = 'pending'
        save!
      else
        # 승인이 필요 없는 경우 바로 승인 완료
        self.status = 'approved'
        self.approved_at = Time.current
        save!
      end
    end
    
    true
  end
  
  def approve!
    return false unless pending?
    
    self.status = 'approved'
    self.approved_at = Time.current
    save!
  end
  
  def reject!(reason)
    return false unless pending?
    
    self.status = 'rejected'
    self.rejected_at = Time.current
    self.rejection_reason = reason
    save!
  end
  
  def cancel!
    return false unless can_cancel?
    
    self.status = 'cancelled'
    save!
  end
  
  def can_cancel?
    draft? || submitted?
  end
  
  # 편집 가능 여부
  def editable?
    draft? || rejected?
  end
  
  # 임시저장
  def save_as_draft(params)
    self.is_draft = true
    self.status = 'draft'
    self.draft_data = params
    self.form_data = params[:form_data] if params[:form_data]
    save(validate: false)
  end
  
  # 임시저장 데이터 복원
  def restore_from_draft
    return unless is_draft? && draft_data.present?
    
    self.form_data = draft_data['form_data'] if draft_data['form_data']
  end
  
  # 필드 값 가져오기
  def field_value(field_key)
    form_data&.dig(field_key)
  end
  
  # 필드 값 설정
  def set_field_value(field_key, value)
    self.form_data ||= {}
    self.form_data[field_key] = value
  end
  
  # 필드 레이블 가져오기
  def field_label(field_key)
    field = request_template&.request_template_fields&.find_by(field_key: field_key)
    field&.field_label || field_key.humanize
  end
  
  # 상태 한글 표시
  def status_name
    STATUSES[status]
  end
  
  # ExpenseItem과 동일한 인터페이스 제공
  def status_display
    status_name
  end
  
  # ===== Approvable 인터페이스 구현 =====
  
  def display_title
    "#{request_template.name} ##{request_number}"
  end
  
  def display_description
    # form_data의 주요 내용을 요약
    if form_data.present?
      key_fields = form_data.slice('usage_purpose', 'target_user', 'application_type', 'reason')
      key_fields.values.compact.first || "신청서"
    else
      "신청서"
    end
  end
  
  # 상태별 배지 클래스
  def status_badge_class
    case status
    when 'draft'
      'bg-secondary'
    when 'submitted'
      'bg-info'
    when 'pending'
      'bg-warning'
    when 'approved'
      'bg-success'
    when 'rejected'
      'bg-danger'
    when 'cancelled'
      'bg-dark'
    else
      'bg-light'
    end
  end
  
  # 진행률 계산
  def progress_percentage
    filled_fields = 0
    total_fields = request_template.request_template_fields.count
    
    return 0 if total_fields == 0
    
    request_template.request_template_fields.each do |field|
      filled_fields += 1 if field_value(field.field_key).present?
    end
    
    ((filled_fields.to_f / total_fields) * 100).round
  end
  
  # 승인 규칙 평가 - 필요한 승인자 그룹 반환
  def evaluate_approval_rules(user = nil)
    return [] unless request_template
    
    required_groups = []
    request_template.request_template_approval_rules.active.each do |rule|
      # 사용자가 이미 이 규칙을 만족하는지 확인
      next if user && rule.already_satisfied_by_user?(user)
      
      # 조건 평가 (현재는 모든 규칙을 필수로 처리)
      required_groups << rule.approver_group
    end
    
    required_groups
  end
  
  # ===== ApprovalPresenter와의 호환성을 위한 추가 메서드 =====
  
  # 금액 관련 (신청서는 일반적으로 금액이 없음)
  def display_amount
    # 특정 신청서 유형에서 금액 필드가 있다면 여기서 처리
    # 예: form_data['amount'] 또는 form_data['requested_amount']
    nil
  end
  
  def formatted_amount
    return nil unless display_amount
    "₩#{display_amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end
  
  # 소유자 정보
  def display_owner
    user
  end
  
  def display_owner_name
    user&.name || '알 수 없음'
  end
  
  def display_organization
    organization || user&.organization
  end
  
  def display_status
    status_display
  end
  
  # 첨부파일 관련
  def attachments
    request_form_attachments
  end
  
  # 메타데이터 (승인 화면에서 추가 정보 표시용)
  def approval_metadata
    {
      template_name: request_template&.name,
      category: request_category&.name,
      request_number: request_number,
      form_data: form_data,
      submitted_at: submitted_at,
      approved_at: approved_at,
      rejected_at: rejected_at
    }
  end
  
  # content 메서드 (일부 뷰에서 사용할 수 있음)
  def content
    display_description
  end
  
  private
  
  def set_title
    return if title.present?
    
    if request_template && user
      self.title = "[#{request_template.request_category.name}] #{request_template.name} - #{user.name}"
    end
  end
  
  def generate_request_number
    return if request_number.present?
    return unless request_template&.auto_numbering?
    
    date_prefix = Date.current.strftime('%Y%m')
    last_number = RequestForm.where("request_number LIKE ?", "REQ-#{date_prefix}-%")
                             .order(:request_number)
                             .last
                             &.request_number
                             &.split('-')
                             &.last
                             &.to_i || 0
    
    self.request_number = "REQ-#{date_prefix}-#{(last_number + 1).to_s.rjust(4, '0')}"
  end
  
  def set_initial_status
    self.status ||= 'draft'
  end
  
  def validate_required_fields
    return unless request_template
    
    request_template.request_template_fields.required.each do |field|
      if field_value(field.field_key).blank?
        errors.add(:base, "#{field.field_label} 필드는 필수입니다.")
      end
    end
  end
  
  def validate_approval_line
    # 삭제 중이면 검증 스킵
    return if marked_for_destruction?
    
    # 승인 규칙이 있는지 확인
    return unless request_template&.request_template_approval_rules&.active&.any?
    
    # 사용자 권한을 고려한 필수 승인 그룹 확인
    # TODO: 추후 ExpenseItem과 공통 로직으로 리팩토링 필요
    required_groups = evaluate_approval_rules(self.user)
    
    # 사용자가 이미 모든 권한을 가지고 있으면 결재선 없이 가능
    return if required_groups.empty?
    
    # 결재선이 없으면 에러
    if approval_line.blank?
      group_names = required_groups.map(&:name).join(', ')
      errors.add(:approval_line, "승인이 필요합니다. 필요한 승인자: #{group_names}")
    end
  end
  
  def create_approval_request_if_needed
    return unless saved_change_to_status?
    return unless status == 'pending'
    return unless approval_line.present?
    return if approval_request.present?
    
    ApprovalRequest.create_with_approval_line(self, approval_line)
  end
  
  # Approvable의 check_can_be_deleted를 오버라이드하여 추가 검증
  def check_can_be_deleted
    super # Approvable의 기본 검증 실행
    
    if status == 'approved'
      errors.add(:base, '승인 완료된 신청서는 삭제할 수 없습니다.')
      throw :abort
    end
  end
  
  public
end