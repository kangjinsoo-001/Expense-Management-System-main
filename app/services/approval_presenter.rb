# frozen_string_literal: true

# 승인 항목을 일관된 방식으로 표시하기 위한 Presenter
# 타입에 관계없이 동일한 인터페이스로 데이터 접근 가능
class ApprovalPresenter
  attr_reader :approvable
  
  def initialize(approvable)
    @approvable = approvable
    raise ArgumentError, "approvable cannot be nil" if approvable.nil?
  end
  
  # ===== 기본 정보 =====
  
  def title
    @approvable.display_title
  rescue NoMethodError
    "#{type_label} ##{@approvable.id}"
  end
  
  def description
    @approvable.display_description
  rescue NoMethodError
    nil
  end
  
  def amount
    @approvable.display_amount
  rescue NoMethodError
    nil
  end
  
  def formatted_amount
    return '-' if amount.nil?
    amount.is_a?(String) ? amount : number_to_currency(amount)
  end
  
  def owner
    @approvable.display_owner
  rescue NoMethodError
    nil
  end
  
  def owner_name
    @approvable.display_owner_name
  rescue NoMethodError
    owner&.name || '알 수 없음'
  end
  
  def organization
    @approvable.display_organization
  rescue NoMethodError
    owner&.organization
  end
  
  def status
    @approvable.display_status
  rescue NoMethodError
    nil
  end
  
  # ===== 타입 정보 =====
  
  def type_code
    @approvable.class.name.underscore
  end
  
  def type_label
    case @approvable.class.name
    when 'ExpenseItem' then '경비'
    when 'ExpenseSheet' then '경비 시트'
    when 'RequestForm' then '신청서'
    when 'PurchaseOrder' then '구매요청'
    when 'LeaveRequest' then '휴가신청'
    when 'Contract' then '계약'
    else @approvable.display_type rescue @approvable.class.model_name.human
    end
  end
  
  def type_badge
    case @approvable.class.name
    when 'ExpenseItem'
      { color: 'blue', icon: 'currency-dollar', label: '경비' }
    when 'ExpenseSheet'
      { color: 'indigo', icon: 'document-text', label: '경비 시트' }
    when 'RequestForm'
      { color: 'purple', icon: 'document-text', label: '신청서' }
    when 'PurchaseOrder'
      { color: 'green', icon: 'shopping-cart', label: '구매' }
    when 'LeaveRequest'
      { color: 'yellow', icon: 'calendar', label: '휴가' }
    when 'Contract'
      { color: 'indigo', icon: 'document-duplicate', label: '계약' }
    else
      { color: 'gray', icon: 'document', label: type_label }
    end
  end
  
  def type_badge_classes
    badge = type_badge
    base_classes = "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium"
    color_classes = case badge[:color]
    when 'blue' then 'bg-blue-100 text-blue-800'
    when 'purple' then 'bg-purple-100 text-purple-800'
    when 'green' then 'bg-green-100 text-green-800'
    when 'yellow' then 'bg-yellow-100 text-yellow-800'
    when 'indigo' then 'bg-indigo-100 text-indigo-800'
    else 'bg-gray-100 text-gray-800'
    end
    
    "#{base_classes} #{color_classes}"
  end
  
  # ===== 부분 템플릿 경로 =====
  
  def detail_partial
    "approvals/types/#{type_code}"
  end
  
  def attachments_partial
    "approvals/attachments/#{type_code}"
  end
  
  def has_custom_detail_partial?
    partial_exists?("approvals/types/_#{type_code}")
  end
  
  def has_custom_attachments_partial?
    partial_exists?("approvals/attachments/_#{type_code}")
  end
  
  # ===== 첨부파일 =====
  
  def attachments
    @approvable.attachments
  rescue NoMethodError
    []
  end
  
  def has_attachments?
    attachments.any?
  end
  
  # ===== 추가 정보 =====
  
  def metadata
    @approvable.approval_metadata
  rescue NoMethodError
    {}
  end
  
  def created_at
    @approvable.created_at
  end
  
  def updated_at
    @approvable.updated_at
  end
  
  # ===== 승인 관련 =====
  
  def approval_request
    @approvable.approval_request
  end
  
  def has_pending_approval?
    @approvable.has_pending_approval?
  rescue NoMethodError
    approval_request&.status_pending?
  end
  
  def is_approved?
    @approvable.is_approved?
  rescue NoMethodError
    approval_request&.status_approved?
  end
  
  def is_rejected?
    @approvable.is_rejected?
  rescue NoMethodError
    approval_request&.status_rejected?
  end
  
  private
  
  def partial_exists?(partial_path)
    # Rails 뷰 경로에서 부분 템플릿 존재 여부 확인
    Rails.root.join('app', 'views', "#{partial_path}.html.erb").exist?
  end
  
  def number_to_currency(amount)
    ActionController::Base.helpers.number_to_currency(amount, unit: "₩", format: "%u%n")
  end
end