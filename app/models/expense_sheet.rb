class ExpenseSheet < ApplicationRecord
  include CacheInvalidation
  include Approvable
  
  belongs_to :user
  belongs_to :organization
  belongs_to :cost_center, optional: true
  belongs_to :approved_by, class_name: 'User', optional: true
  has_many :expense_items, dependent: :destroy
  has_many :audit_logs, as: :auditable, dependent: :destroy
  has_many_attached :pdf_attachments
  has_many :pdf_analysis_results, dependent: :destroy
  
  # 결재 관련 관계
  belongs_to :approval_line, optional: true
  has_many :approval_requests, through: :expense_items
  # Polymorphic 관계 추가
  has_many :direct_approval_requests, class_name: 'ApprovalRequest', as: :approvable, dependent: :destroy
  has_one :approval_request, as: :approvable, dependent: :destroy
  # 승인 이력 관계
  has_many :expense_approvals, -> { for_expense_sheets }, 
           class_name: 'ExpenseApproval', 
           foreign_key: :approvable_id,
           primary_key: :id
  
  # 첨부파일 관리 시스템 관계
  has_many :expense_sheet_attachments, dependent: :destroy
  
  # 검증 이력 관계
  has_many :validation_histories, class_name: 'ExpenseValidationHistory', dependent: :destroy

  # 상태 enum 정의
  enum :status, {
    draft: 'draft',
    submitted: 'submitted',
    approved: 'approved',
    rejected: 'rejected',
    closed: 'closed'
  }, prefix: true

  validates :year, presence: true, numericality: { greater_than: 2000 }
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :user_id, uniqueness: { scope: [:year, :month], message: '해당 월에 이미 경비 시트가 존재합니다' }
  validate :validate_approval_rules, if: :approval_line_id_changed?

  scope :by_status, ->(status) { where(status: status) }
  scope :by_period, ->(year, month) { where(year: year, month: month) }
  scope :recent, -> { order(year: :desc, month: :desc) }
  scope :editable_statuses, -> { where(status: %w[draft rejected]) }
  scope :for_approval, -> { where(status: 'submitted') }
  
  # 쿼리 최적화를 위한 추가 scope
  scope :with_associations, -> { includes(:user, :organization, :expense_items) }
  scope :with_approval_info, -> { includes(:approved_by) }
  scope :with_items_count, -> { 
    left_joins(:expense_items)
      .group(:id)
      .select('expense_sheets.*, COUNT(expense_items.id) as items_count') 
  }

  before_save :calculate_total_amount
  before_validation :set_default_year_month, on: :create
  before_validation :set_organization_from_user, on: :create

  def period
    "#{year}년 #{month}월"
  end
  
  def description
    "#{period} 경비 정산"
  end

  def editable?
    %w[draft rejected].include?(status)
  end

  def submittable?
    status == 'draft' && expense_items.any? && !has_pending_approvals?
  end

  # enum 상태 메서드들 (Rails enum이 자동 생성하지 않는 경우를 위해)
  def submitted?
    status == 'submitted'
  end

  def closed?
    status == 'closed'
  end

  def approved?
    status == 'approved'
  end

  def rejected?
    status == 'rejected'
  end

  def draft?
    status == 'draft'
  end
  
  # 검증 관련 메서드
  def validation_status_label
    case validation_status
    when 'validated'
      '검증 완료'
    when 'needs_review'
      '검토 필요'
    when 'failed'
      '검증 실패'
    when 'pending'
      '검증 대기'
    else
      '미검증'
    end
  end
  
  def validation_badge_class
    case validation_status
    when 'validated'
      'bg-green-100 text-green-800'
    when 'needs_review'
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
    validation_status == 'needs_review'
  end
  
  def all_items_validated?
    expense_items.all?(&:validation_passed?)
  end
  
  def validation_summary
    total = expense_items.count
    return { total: 0, validated: 0, warning: 0, failed: 0, pending: 0 } if total == 0
    
    {
      total: total,
      validated: expense_items.where(validation_status: 'validated').count,
      warning: expense_items.where(validation_status: 'warning').count,
      failed: expense_items.where(validation_status: 'failed').count,
      pending: expense_items.where(validation_status: ['pending', nil]).count
    }
  end
  
  # 승인 대기 중인 항목이 있는지 확인
  def has_pending_approvals?
    expense_items.joins(:approval_request)
                 .where(approval_requests: { status: 'pending' })
                 .exists?
  end
  
  # 승인 대기 중인 항목 수
  def pending_approval_count
    expense_items.joins(:approval_request)
                 .where(approval_requests: { status: 'pending' })
                 .count
  end
  
  # 제출 차단 이유
  def submission_blocked_reason
    return "경비 항목을 추가해주세요" if expense_items.empty?
    return "승인 대기 중인 항목이 #{pending_approval_count}개 있습니다" if has_pending_approvals?
    return "이미 제출된 시트입니다" unless status == 'draft'
    nil
  end
  
  # 승인이 필요하지만 요청하지 않은 항목이 있는지 확인
  def has_unapproved_items_requiring_approval?
    expense_items.any? do |item|
      # 결재가 필요한데 승인 요청이 없거나 반려된 경우
      if item.expense_code&.expense_code_approval_rules&.active&.exists?
        !item.approval_request.present? || item.approval_request.status_rejected?
      else
        false
      end
    end
  end

  def approvable?
    status == 'submitted'
  end

  def submit!(submitter = nil)
    return false unless submittable?
    
    # 제출 전 모든 경비 항목 검증 (임시저장 제외)
    invalid_items = expense_items.where(is_valid: false, is_draft: false)
    if invalid_items.exists?
      errors.add(:base, "검증되지 않은 경비 항목이 #{invalid_items.count}개 있습니다 (임시저장 제외)")
      return false
    end
    
    # 결재선 필수 확인
    if approval_line_id.blank?
      errors.add(:base, "결재선을 선택해주세요.")
      return false
    end
    
    # 결재선 검증
    if approval_line
      validator = ExpenseSheetApprovalValidator.new
      result = validator.validate(self, approval_line)
      unless result[:valid]
        result[:errors].each do |error|
          errors.add(:base, error)
        end
        return false
      end
    end

    transaction do
      # 기존 취소된 ApprovalRequest가 있으면 삭제 (새로운 승인 요청을 위해)
      cancelled_requests = ApprovalRequest.where(
        approvable: self,
        status: 'cancelled'
      )
      
      if cancelled_requests.any?
        Rails.logger.info "경비 시트 ##{id}의 취소된 #{cancelled_requests.count}개 ApprovalRequest 삭제"
        cancelled_requests.destroy_all
      end
      
      # 승인 요청 생성
      if approval_line
        ApprovalRequest.create_with_approval_line(self, approval_line)
      end
      
      update!(status: 'submitted', submitted_at: Time.current)
      create_audit_log('submit', submitter || user, { from: 'draft', to: 'submitted' })
      
      # 대시보드 실시간 업데이트
      if defined?(DashboardBroadcastService)
        DashboardBroadcastService.broadcast_expense_sheet_update(self)
      end
    end
    true
  rescue => e
    errors.add(:base, "제출 중 오류가 발생했습니다: #{e.message}")
    false
  end

  def approve!(approver)
    return false unless approvable?

    transaction do
      update!(
        status: 'approved',
        approved_at: Time.current,
        approved_by: approver
      )
      create_audit_log('approve', approver, { from: 'submitted', to: 'approved' })
      
      # 대시보드 실시간 업데이트
      if defined?(DashboardBroadcastService)
        DashboardBroadcastService.broadcast_expense_sheet_update(self)
      end
    end
    true
  rescue => e
    errors.add(:base, "승인 중 오류가 발생했습니다: #{e.message}")
    false
  end

  def reject!(approver, reason)
    return false unless approvable?

    transaction do
      update!(
        status: 'rejected',
        approved_at: Time.current,
        approved_by: approver,
        rejection_reason: reason
      )
      create_audit_log('reject', approver, { 
        from: 'submitted', 
        to: 'rejected',
        reason: reason 
      })
    end
    true
  rescue => e
    errors.add(:base, "반려 중 오류가 발생했습니다: #{e.message}")
    false
  end

  def close!
    return false unless status == 'approved'
    
    transaction do
      update!(status: 'closed')
      create_audit_log('close', user, { from: 'approved', to: 'closed' })
    end
    true
  rescue => e
    errors.add(:base, "마감 중 오류가 발생했습니다: #{e.message}")
    false
  end
  
  # 최신 검증 이력 가져오기
  def latest_validation
    validation_histories.recent.first
  end
  
  # 검증 시도 횟수
  def validation_count
    validation_histories.count
  end
  
  # 제출 취소 메서드
  def cancel_submission!(canceller = nil)
    return false unless status == 'submitted'
    
    # 승인 완료된 항목이 있어도 경비 시트 취소는 가능
    # 경비 항목의 승인 상태는 유지하되, 경비 시트만 draft로 변경
    
    transaction do
      # 1. 경비 시트 상태를 draft로 되돌림 (경비 항목 승인 상태는 유지)
      update!(status: 'draft', submitted_at: nil)
      
      # 2. ApprovalRequest 취소 처리 (이력 보존)
      # polymorphic 관계를 사용하여 경비 시트의 ApprovalRequest를 찾아서 취소
      approval_requests_to_cancel = ApprovalRequest.where(
        approvable: self,
        status: 'pending'
      )
      
      if approval_requests_to_cancel.any?
        approval_requests_to_cancel.update_all(status: 'cancelled')
        Rails.logger.info "경비 시트 ##{id}의 #{approval_requests_to_cancel.count}개 ApprovalRequest를 취소 처리"
      end
      
      # 3. 승인된 항목 수 확인 (로그용)
      approved_count = expense_items.joins(:approval_request)
                                    .where(approval_requests: { status: 'approved' })
                                    .count
      
      # 4. 감사 로그 생성
      log_data = { 
        from: 'submitted', 
        to: 'draft',
        reason: '제출 취소'
      }
      
      # 승인된 항목이 있는 경우 로그에 기록
      if approved_count > 0
        log_data[:note] = "승인 완료된 #{approved_count}개 항목 포함. 경비 항목 승인 상태는 유지됨."
      end
      
      create_audit_log('cancel_submission', canceller || user, log_data)
      
      # 5. 대시보드 실시간 업데이트
      if defined?(DashboardBroadcastService)
        DashboardBroadcastService.broadcast_expense_sheet_update(self)
      end
    end
    true
  rescue => e
    errors.add(:base, "제출 취소 중 오류가 발생했습니다: #{e.message}")
    false
  end

  def calculate_total_amount
    self.total_amount = expense_items.sum(:amount)
  end

  def validate_all_items
    expense_items.each(&:validate_item)
  end

  def has_invalid_items?
    # 임시저장 항목은 제외하고 검증되지 않은 항목만 체크
    expense_items.where(is_valid: false, is_draft: false).exists?
  end

  def invalid_items_count
    # 임시저장 항목은 제외하고 검증되지 않은 항목만 카운트
    expense_items.where(is_valid: false, is_draft: false).count
  end

  def valid_items_count
    # 임시저장이 아닌 항목 중 검증된 항목만 카운트
    expense_items.where(is_valid: true, is_draft: false).count
  end

  def create_audit_log(action, user, metadata = {})
    audit_logs.create!(
      user: user,
      action: action,
      changed_from: metadata[:from],
      changed_to: metadata[:to],
      metadata: metadata.except(:from, :to)
    )
  end

  # ===== Approvable 인터페이스 구현 =====
  
  def display_title
    item_count = expense_items.where(is_draft: false).count
    "총액 #{ActionController::Base.helpers.number_to_currency(total_amount, unit: '₩', format: '%u%n')} (#{item_count}항목)"
  end
  
  def display_description
    "#{user.name} #{year}년 #{month}월 경비 시트"
  end
  
  def display_amount
    total_amount
  end
  
  def display_owner
    user
  end
  
  def display_owner_name
    user&.name || '알 수 없음'
  end

  private

  def set_default_year_month
    self.year ||= Date.current.year
    self.month ||= Date.current.month
  end
  
  def set_organization_from_user
    self.organization ||= user&.organization
  end
  
  public
  
  # 결재 상태 관련 메서드
  def has_approval_items?
    expense_items.joins(:approval_request).exists?
  end
  
  def approval_status_summary
    return nil unless has_approval_items?
    
    # 모든 결재 요청의 상태를 확인
    statuses = approval_requests.pluck(:status).uniq
    
    if statuses.include?('rejected')
      'rejected'
    elsif statuses.include?('pending')
      'pending'
    elsif statuses.all? { |s| s == 'approved' }
      'approved'
    else
      'pending'
    end
  end
  
  def current_approval_step_info
    # 진행 중인 결재 정보
    pending_approvals = approval_requests.includes(approval_line: { approval_line_steps: :approver })
                                       .where(status: 'pending')
    
    return nil if pending_approvals.empty?
    
    # 현재 대기 중인 승인자들 목록
    current_approvers = []
    pending_approvals.each do |approval|
      approval.current_step_approvers.approvers.each do |step|
        current_approvers << step.approver.name
      end
    end
    
    current_approvers.uniq.join(', ')
  end
  
  def approval_progress_text
    return nil unless has_approval_items?
    
    case approval_status_summary
    when 'approved'
      '결재완료'
    when 'rejected'
      '반려됨'
    when 'pending'
      approvers = current_approval_step_info
      approvers ? "결재진행중 - #{approvers}" : '결재진행중'
    else
      nil
    end
  end
  
  # 결재가 필요한지 확인
  def requires_approval?
    expense_items.any? do |item|
      item.expense_code&.expense_code_approval_rules&.active&.exists?
    end
  end
  
  # 모든 경비 항목의 결재선 검증
  def validate_approval_lines
    validation_errors = []
    
    expense_items.includes(:expense_code, :approval_line).each do |item|
      # 승인 규칙이 있는 경비 코드인지 확인
      if item.expense_code&.expense_code_approval_rules&.active&.exists?
        # 결재선이 지정되지 않은 경우
        if item.approval_line_id.blank? && approval_line_id.blank?
          validation_errors << "#{item.expense_code.name_with_code}: 결재선이 필요합니다"
          next
        end
        
        # 결재선 검증
        validator = ExpenseValidation::ApprovalLineValidator.new(item)
        unless validator.validate
          validator.error_messages.each do |message|
            validation_errors << "#{item.expense_code.name_with_code}: #{message}"
          end
        end
      end
    end
    
    if validation_errors.any?
      validation_errors.each { |error| errors.add(:base, error) }
      return false
    end
    
    true
  end
  
  private
  
  def validate_approval_rules
    return unless approval_line
    
    validator = ExpenseSheetApprovalValidator.new
    result = validator.validate(self, approval_line)
    
    if result[:errors].any?
      result[:errors].each do |error|
        errors.add(:approval_line_id, error)
      end
    end
  end
end