class ApprovalRequest < ApplicationRecord
  # Polymorphic 관계 설정
  belongs_to :approvable, polymorphic: true
  belongs_to :expense_item, optional: true  # 기존 관계 유지 (호환성)
  belongs_to :approval_line, optional: true  # 이제 optional로 변경
  
  # 관계 설정
  has_many :approval_histories, dependent: :destroy
  has_many :approval_request_steps, dependent: :destroy
  
  # Enum 정의
  enum :status, { 
    pending: 'pending',      # 진행중
    approved: 'approved',    # 승인 완료
    rejected: 'rejected',    # 반려됨
    cancelled: 'cancelled'   # 취소됨
  }, prefix: true
  
  # 검증
  validates :current_step, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :approvable_type, presence: true
  validates :approvable_id, presence: true
  validates :approvable_id, uniqueness: { 
    scope: :approvable_type,
    message: '하나의 항목은 하나의 승인 요청만 가질 수 있습니다' 
  }
  
  # 스코프
  scope :in_progress, -> { where(status: 'pending') }
  scope :completed, -> { where(status: ['approved', 'rejected']) }
  scope :for_approver, ->(user) {
    # 현재 단계의 승인자이면서 아직 처리하지 않은 항목들
    # NOT EXISTS 서브쿼리를 사용하여 이미 처리한 항목 제외
    joins(:approval_request_steps)
      .where("approval_request_steps.approver_id = ? AND approval_request_steps.step_order = approval_requests.current_step", user.id)
      .where(status: 'pending')
      .where("NOT EXISTS (
        SELECT 1 FROM approval_histories 
        WHERE approval_histories.approval_request_id = approval_requests.id 
        AND approval_histories.approver_id = ? 
        AND approval_histories.step_order = approval_requests.current_step
      )", user.id)
      .distinct
  }
  
  # 클래스 메서드 - 결재선 복제하여 승인 요청 생성
  def self.create_with_approval_line(approvable, approval_line)
    transaction do
      request = create!(
        approvable: approvable,  # Polymorphic 관계 사용
        expense_item: approvable.is_a?(ExpenseItem) ? approvable : nil,  # 호환성 유지
        approval_line_id: approval_line.id,  # 참조용으로 유지
        approval_line_name: approval_line.name,
        status: 'pending',
        current_step: 1
      )
      
      # 결재선 스텝 복제
      approval_line.approval_line_steps.each do |line_step|
        # approval_type 매핑: single_allowed -> any_one
        approval_type = nil
        if line_step.approval_type.present?
          approval_type = line_step.approval_type == 'single_allowed' ? 'any_one' : line_step.approval_type.to_s
        end
        
        request.approval_request_steps.create!(
          approver_id: line_step.approver_id,
          step_order: line_step.step_order,
          role: line_step.role.to_s,  # enum을 문자열로 변환
          approval_type: approval_type,
          status: 'pending'
        )
      end
      
      # JSON 데이터로도 저장 (백업용)
      steps_data = approval_line.approval_line_steps.map do |step|
        {
          approver_id: step.approver_id,
          approver_name: step.approver.name,
          step_order: step.step_order,
          role: step.role,
          approval_type: step.approval_type
        }
      end
      request.update_column(:approval_steps_data, steps_data)
      
      # 참조자만 있는 단계는 자동으로 건너뛰기
      request.skip_reference_only_steps!
      
      request
    end
  end
  
  # 인스턴스 메서드
  # 참조자만 있는 단계 건너뛰기
  def skip_reference_only_steps!
    while current_step <= max_step
      # 현재 단계에 승인자가 있는지 확인
      approvers_count = approval_request_steps.for_step(current_step).approvers.count
      
      if approvers_count == 0
        # 참조자만 있는 단계
        Rails.logger.info "ApprovalRequest ##{id}: Skipping reference-only step #{current_step}"
        
        # 참조 이력 기록 (선택적)
        referrers = approval_request_steps.for_step(current_step).referrers
        referrers.each do |referrer|
          approval_histories.create!(
            approver: referrer.approver,
            action: 'view',
            step_order: current_step,
            role: 'reference',
            approved_at: Time.current,
            comment: '참조 단계 (자동 건너뛰기)'
          )
        end
        
        # 다음 단계로 이동
        if current_step < max_step
          update_column(:current_step, current_step + 1)
        else
          # 모든 단계가 참조자만인 경우 (이런 경우는 없어야 하지만)
          Rails.logger.warn "ApprovalRequest ##{id}: All steps are reference-only!"
          break
        end
      else
        # 승인자가 있는 단계를 찾았으므로 멈춤
        break
      end
    end
  end
  
  def current_step_approvers
    approval_request_steps.for_step(current_step)
  end
  
  def current_step_approval_type
    approvers = approval_request_steps.for_step(current_step).approvers
    return nil if approvers.count <= 1
    
    approvers.first.approval_type
  end
  
  def can_proceed_to_next_step?
    return false unless status_pending?
    
    approval_type = current_step_approval_type
    current_approvals = approval_histories.where(step_order: current_step, action: 'approve')
    
    case approval_type
    when 'all_required'
      current_approvals.count == current_step_approvers.approvers.count
    when 'single_allowed'
      current_approvals.exists?
    else
      # 승인자가 1명인 경우
      current_approvals.exists?
    end
  end
  
  def max_step
    approval_request_steps.maximum(:step_order) || 1
  end
  
  def completed?
    status_approved? || status_rejected?
  end
  
  def progress_percentage
    return 100 if completed?
    return 0 if max_step == 0
    
    ((current_step - 1) * 100.0 / max_step).round
  end
  
  def current_status_display
    case status
    when 'pending'
      "#{current_step}/#{max_step} 단계 진행중"
    when 'approved'
      '승인 완료'
    when 'rejected'
      '반려됨'
    when 'cancelled'
      '취소됨'
    else
      status
    end
  end
  
  # 현재 단계의 승인자 이름들 반환
  def current_approver_names
    return '완료' if status_approved?
    return '취소됨' if status_cancelled?
    return '반려됨' if status_rejected?
    
    # 현재 단계의 승인자들 가져오기
    current_approvers = approval_request_steps.for_step(current_step).approvers
    
    if current_approvers.any?
      current_approvers.map { |step| step.approver.name }.join(', ')
    else
      '대기중'
    end
  end
  
  def pending_approvers
    return [] unless status_pending?
    approval_request_steps.for_step(current_step).approvers.map(&:approver)
  end
  
  # 현재 승인 대기 중인 승인자 (첫 번째 승인자)
  def current_approver
    return nil unless status_pending?
    pending_approvers.first
  end
  
  def has_been_processed_by?(user)
    # ExpenseItem의 재승인 상황을 고려한 처리 여부 확인
    if approvable.is_a?(ExpenseItem) && approvable.needs_reapproval?
      # 재승인 상황에서는 재승인 요청 이후의 이력만 확인
      # 예산 승인 시점 이후의 이력만 체크
      approval_histories.where(approver_id: user.id)
                       .where('approved_at > ?', approvable.budget_approved_at || Time.current)
                       .exists?
    else
      approval_histories.where(approver_id: user.id).exists?
    end
  end
  
  def can_be_approved_by?(user)
    return false unless status_pending?
    
    # 현재 단계의 승인자인지 확인
    approval_request_steps.for_step(current_step).approvers.where(approver_id: user.id).exists? &&
      !has_been_processed_by?(user)
  end
  
  def can_be_viewed_by?(user)
    # 현재 단계의 참조자인지 확인
    approval_request_steps.for_step(current_step).referrers.where(approver_id: user.id).exists?
  end
  
  # 승인 처리 메서드
  def process_approval(approver, comment = nil)
    ActiveRecord::Base.transaction do
      # 락을 획득하여 동시성 제어
      self.lock!
      
      raise ArgumentError, '승인 권한이 없습니다' unless can_be_approved_by?(approver)
      
      # single_allowed 타입에서 이미 승인이 있는지 확인
      current_approval_type = approval_request_steps.for_step(current_step).approvers.first&.approval_type
      
      # ExpenseItem의 재승인 상황에서는 이전 예산 승인 이력 제외
      if approvable.is_a?(ExpenseItem) && approvable.needs_reapproval?
        current_approvals = approval_histories.where(step_order: current_step, action: 'approve')
                                            .where('approved_at > ?', approvable.budget_approved_at || Time.current)
      else
        current_approvals = approval_histories.where(step_order: current_step, action: 'approve')
      end
      
      if current_approval_type == 'single_allowed' && current_approvals.exists?
        raise ArgumentError, '이미 승인되었습니다'
      end
      
      # ApprovalHistory 생성
      approval_histories.create!(
        approver: approver,
        action: 'approve',
        comment: comment,
        step_order: current_step,
        role: 'approve',
        approved_at: Time.current
      )
      
      # 다음 단계로 진행 가능한지 확인
      if can_proceed_to_next_step?
        if current_step < max_step
          # 다음 단계로 진행
          update!(current_step: current_step + 1)
          # 참조자만 있는 단계는 자동으로 건너뛰기
          skip_reference_only_steps!
        else
          # 모든 단계 완료 - 승인 완료 처리
          update!(status: 'approved')
          
          # 타임스탬프 업데이트 (ExpenseItem인 경우에만)
          if approvable.is_a?(ExpenseItem)
            if approvable.needs_reapproval?
              # 재승인 완료 - 실제 승인 시간 업데이트, 초과 플래그는 유지
              approvable.update_columns(
                actual_approved_at: Time.current
              )
            elsif approvable.budget_mode?
              # 예산 승인
              approvable.update_column(:budget_approved_at, Time.current)
            else
              # 일반 승인
              approvable.update_column(:actual_approved_at, Time.current)
            end
          elsif approvable.is_a?(RequestForm)
            # RequestForm 승인 완료 처리
            approvable.update_columns(
              status: 'approved',
              approved_at: Time.current
            )
          elsif approvable.is_a?(ExpenseSheet)
            # ExpenseSheet 승인 완료 처리
            approvable.update_columns(
              status: 'approved',
              approved_at: Time.current
            )
          end
        end
      end
    end
    
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, "승인 처리 중 오류가 발생했습니다: #{e.message}")
    false
  end
  
  # 반려 처리 메서드
  def process_rejection(approver, comment)
    ActiveRecord::Base.transaction do
      # 락을 획득하여 동시성 제어
      self.lock!
      
      raise ArgumentError, '승인 권한이 없습니다' unless can_be_approved_by?(approver)
      raise ArgumentError, '반려 사유를 입력해주세요' if comment.blank?
      
      # ApprovalHistory 생성
      approval_histories.create!(
        approver: approver,
        action: 'reject',
        comment: comment,
        step_order: current_step,
        role: 'approve',
        approved_at: Time.current
      )
      
      # 반려 처리
      update!(status: 'rejected')
      
      # RequestForm인 경우 상태 업데이트
      if approvable.is_a?(RequestForm)
        approvable.update_columns(
          status: 'rejected',
          rejected_at: Time.current,
          rejection_reason: comment
        )
      elsif approvable.is_a?(ExpenseSheet)
        # ExpenseSheet인 경우 상태 업데이트
        approvable.update_columns(
          status: 'rejected',
          rejected_at: Time.current
        )
      end
    end
    
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, "반려 처리 중 오류가 발생했습니다: #{e.message}")
    false
  end
  
  # 승인 요청 취소
  def cancel!
    return false unless status_pending?
    
    transaction do
      # 1. 승인 요청 상태를 cancelled로 변경
      update!(
        status: 'cancelled', 
        cancelled_at: Time.current,
        completed_at: Time.current
      )
      
      # 2. 승인 이력에 취소 기록 추가
      cancel_user = if approvable.is_a?(ExpenseItem)
                     approvable.expense_sheet.user
                   elsif approvable.is_a?(RequestForm)
                     approvable.user
                   else
                     approvable.try(:user)
                   end
                   
      approval_histories.create!(
        approver: cancel_user,
        action: 'cancel',
        step_order: current_step,
        role: 'approve',  # role 필드 추가
        comment: '제출 취소로 인한 승인 프로세스 중단'
      )
      
      # 3. 모든 대기 중인 스텝을 cancelled로 변경
      approval_request_steps.where(status: 'pending').update_all(
        status: 'cancelled',
        updated_at: Time.current
      )
    end
    true
  rescue => e
    Rails.logger.error "ApprovalRequest#cancel! failed: #{e.message}"
    false
  end
  
  # 참조자 열람 기록
  def record_view(user)
    return unless can_be_viewed_by?(user)
    return if approval_histories.where(approver: user, action: 'view').exists?
    
    approval_histories.create!(
      approver: user,
      action: 'view',
      step_order: current_step,
      role: 'reference',
      approved_at: Time.current
    )
  end
end
