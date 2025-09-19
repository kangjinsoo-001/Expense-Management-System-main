# frozen_string_literal: true

module ApprovalsHelper
  # ApprovalPresenter 인스턴스 생성
  def approval_presenter(approvable)
    return nil if approvable.nil?
    ApprovalPresenter.new(approvable)
  end
  
  # 타입별 상세 정보 렌더링
  def render_approval_detail(approvable)
    return content_tag(:div, '항목을 찾을 수 없습니다', class: 'text-gray-500') if approvable.nil?
    
    presenter = approval_presenter(approvable)
    
    # 커스텀 부분 템플릿이 있으면 사용, 없으면 기본 템플릿 사용
    if presenter.has_custom_detail_partial?
      render partial: presenter.detail_partial, locals: { item: approvable, presenter: presenter }
    else
      render partial: 'approvals/types/default', locals: { item: approvable, presenter: presenter }
    end
  rescue ActionView::MissingTemplate => e
    Rails.logger.error "Missing template for approval detail: #{e.message}"
    render partial: 'approvals/types/default', locals: { item: approvable, presenter: presenter }
  end
  
  # 타입별 첨부파일 렌더링
  def render_approval_attachments(approvable)
    return nil unless approvable
    
    presenter = approval_presenter(approvable)
    return nil unless presenter.has_attachments?
    
    # 커스텀 첨부파일 템플릿이 있으면 사용, 없으면 기본 템플릿 사용
    if presenter.has_custom_attachments_partial?
      render partial: presenter.attachments_partial, 
             locals: { attachments: presenter.attachments, presenter: presenter }
    else
      render partial: 'approvals/attachments/default', 
             locals: { attachments: presenter.attachments, presenter: presenter }
    end
  rescue ActionView::MissingTemplate => e
    Rails.logger.error "Missing template for attachments: #{e.message}"
    render partial: 'approvals/attachments/default', 
           locals: { attachments: presenter.attachments, presenter: presenter }
  end
  
  # 타입 배지 렌더링
  def approval_type_badge(approvable)
    return nil unless approvable
    
    presenter = approval_presenter(approvable)
    badge = presenter.type_badge
    
    content_tag :span, class: presenter.type_badge_classes do
      badge[:label]
    end
  end
  
  # 승인 상태 배지
  def approval_status_badge(status)
    status_colors = {
      'pending' => 'bg-yellow-100 text-yellow-800',
      'approved' => 'bg-green-100 text-green-800',
      'rejected' => 'bg-red-100 text-red-800',
      'cancelled' => 'bg-gray-100 text-gray-800'
    }
    
    status_text = {
      'pending' => '승인 대기',
      'approved' => '승인 완료',
      'rejected' => '반려됨',
      'cancelled' => '취소됨'
    }
    
    color_class = status_colors[status] || 'bg-gray-100 text-gray-800'
    text = status_text[status] || status
    
    content_tag :span, text, 
                class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{color_class}"
  end
  
  # 금액 표시 (nil-safe)
  def display_approval_amount(approvable)
    return '-' unless approvable
    
    presenter = approval_presenter(approvable)
    presenter.formatted_amount
  end
  
  # 소유자 표시 (nil-safe)
  def display_approval_owner(approvable)
    return '알 수 없음' unless approvable
    
    presenter = approval_presenter(approvable)
    presenter.owner_name
  end
  
  # 승인 요청 목록용 테이블 행 렌더링
  def render_approval_request_row(request, options = {})
    presenter = approval_presenter(request.approvable)
    return '' unless presenter
    
    render partial: 'approvals/list/table_row', locals: { 
      request: request, 
      presenter: presenter,
      show_checkbox: options[:show_checkbox] || false,
      show_requester: options[:show_requester] || false,
      show_current_approver: options[:show_current_approver] || false
    }
  end
  
  # 승인 요청 목록용 카드 렌더링
  def render_approval_request_card(request, options = {})
    presenter = approval_presenter(request.approvable)
    return '' unless presenter
    
    render partial: 'approvals/list/card', locals: { 
      request: request, 
      presenter: presenter,
      show_checkbox: options[:show_checkbox] || false
    }
  end
end