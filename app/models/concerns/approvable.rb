# frozen_string_literal: true

# 승인 가능한 모델들의 공통 인터페이스를 정의하는 Concern
# 새로운 승인 타입 추가 시 이 모듈을 include하고 필수 메서드를 구현
module Approvable
  extend ActiveSupport::Concern

  included do
    # Polymorphic 관계 설정
    has_many :approval_requests, as: :approvable, dependent: :destroy
    has_one :approval_request, -> { order(created_at: :desc) }, 
            as: :approvable, dependent: :destroy
    
    # 승인 요청 전 검증
    before_destroy :check_can_be_deleted
  end

  # ===== 필수 구현 메서드 (각 모델에서 반드시 오버라이드) =====
  
  # 표시용 제목
  def display_title
    raise NotImplementedError, "#{self.class.name}에서 display_title 메서드를 구현해야 합니다"
  end
  
  # 표시용 설명
  def display_description
    raise NotImplementedError, "#{self.class.name}에서 display_description 메서드를 구현해야 합니다"
  end
  
  # ===== 선택적 오버라이드 메서드 (기본값 제공) =====
  
  # 금액 (금액이 없는 타입은 nil 반환)
  def display_amount
    nil
  end
  
  # 타입 표시명
  def display_type
    self.class.model_name.human
  end
  
  # 타입 코드 (뷰에서 CSS 클래스 등에 사용)
  def display_type_code
    self.class.name.underscore
  end
  
  # 소유자
  def display_owner
    if respond_to?(:user)
      user
    elsif respond_to?(:expense_sheet)
      expense_sheet&.user
    else
      nil
    end
  end
  
  # 소유자명
  def display_owner_name
    display_owner&.name || '알 수 없음'
  end
  
  # 조직
  def display_organization
    owner = display_owner
    owner&.organization
  end
  
  # 첨부파일 (첨부파일이 없는 타입은 빈 배열 반환)
  def attachments
    if respond_to?(:expense_attachments)
      expense_attachments
    elsif respond_to?(:request_form_attachments)
      request_form_attachments
    else
      []
    end
  end
  
  # 승인 시 필요한 추가 메타데이터
  def approval_metadata
    {}
  end
  
  # 상태 표시 (있는 경우)
  def display_status
    if respond_to?(:status_display)
      status_display
    elsif respond_to?(:status_name)
      status_name
    elsif respond_to?(:status)
      status
    else
      nil
    end
  end
  
  # ===== 공통 비즈니스 로직 =====
  
  # 승인 중인지 확인
  def has_pending_approval?
    approval_request.present? && approval_request.status_pending?
  end
  
  # 승인 완료 여부
  def is_approved?
    approval_request.present? && approval_request.status_approved?
  end
  
  # 반려 여부
  def is_rejected?
    approval_request.present? && approval_request.status_rejected?
  end
  
  # 삭제 가능 여부 확인
  def can_be_deleted?
    !has_pending_approval?
  end
  
  # 승인 요청 취소
  def cancel_approval_request!
    return false unless has_pending_approval?
    
    ActiveRecord::Base.transaction do
      approval_request.update!(status: 'cancelled')
      update!(status: 'cancelled') if respond_to?(:status=)
      true
    end
  rescue => e
    Rails.logger.error "승인 요청 취소 실패: #{e.message}"
    false
  end
  
  private
  
  # 삭제 전 승인 상태 확인
  def check_can_be_deleted
    if has_pending_approval?
      errors.add(:base, '승인 진행 중인 항목은 삭제할 수 없습니다. 먼저 승인 요청을 취소해주세요.')
      throw(:abort)
    end
  end
end