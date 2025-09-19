module ApplicationHelper
  def format_currency(amount)
    return "₩0" if amount.nil? || amount == 0
    
    # 천 단위 구분 쉼표 추가
    formatted = amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    "₩#{formatted}"
  end

  def expense_sheet_status_class(status)
    case status
    when 'draft'
      'bg-gray-100 text-gray-800'
    when 'submitted'
      'bg-yellow-100 text-yellow-800'
    when 'approved'
      'bg-green-100 text-green-800'
    when 'rejected'
      'bg-red-100 text-red-800'
    when 'closed'
      'bg-blue-100 text-blue-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  def expense_sheet_status_text(status)
    case status
    when 'draft'
      '작성중'
    when 'submitted'
      '제출됨'
    when 'approved'
      '승인됨'
    when 'rejected'
      '반려됨'
    when 'closed'
      '마감됨'
    else
      status
    end
  end

  # 결재선 역할별 아이콘 반환
  def approval_role_icon(role)
    case role
    when 'approve'
      'check-circle'  # 승인자
    when 'reference'
      'eye'           # 참조자
    else
      'user'          # 기본
    end
  end

  # 결재선 역할별 색상 클래스 반환
  def approval_role_color(role)
    case role
    when 'approve'
      'text-blue-600'   # 승인자는 파란색
    when 'reference'
      'text-gray-500'   # 참조자는 회색
    else
      'text-gray-600'   # 기본
    end
  end

  # 승인 방식별 아이콘 반환
  def approval_type_icon(approval_type)
    case approval_type
    when 'all_required'
      'user-group'      # 전체 승인 필요
    when 'single_allowed'
      'user'            # 단일 승인 가능
    else
      'users'           # 기본
    end
  end

  # 승인 방식별 설명 텍스트
  def approval_type_text(approval_type)
    case approval_type
    when 'all_required'
      '전체 승인 필요'
    when 'single_allowed'
      '단일 승인 가능'
    else
      '순차 승인'
    end
  end

  # 결재 상태별 색상 클래스
  def approval_status_color(status)
    case status
    when 'pending'
      'text-blue-600 bg-blue-50'
    when 'approved'
      'text-green-600 bg-green-50'
    when 'rejected'
      'text-red-600 bg-red-50'
    when 'cancelled'
      'text-gray-600 bg-gray-50'
    else
      'text-gray-600 bg-gray-50'
    end
  end

  # 결재 액션별 아이콘
  def approval_action_icon(action)
    case action
    when 'approve'
      'check'
    when 'reject'
      'x-mark'
    when 'view'
      'eye'
    else
      'document'
    end
  end

  # 네비게이션 링크 클래스 헬퍼
  def nav_link_class(path)
    base_classes = "px-3 py-2 rounded-md text-sm font-medium transition-all duration-200"
    
    # 현재 경로 확인 (approvals와 admin 경로 특별 처리)
    is_current = if path == approvals_path
                   request.path.start_with?('/approvals')
                 elsif path == admin_root_path
                   request.path.start_with?('/admin')
                 else
                   current_page?(path)
                 end
    
    if is_current
      "#{base_classes} bg-gray-100 text-gray-900"
    else
      "#{base_classes} text-gray-700 hover:bg-gray-50 hover:text-gray-900"
    end
  end
  
  # 모바일 네비게이션 링크 클래스 헬퍼
  def mobile_nav_link_class(path)
    base_classes = "flex items-center gap-3 px-3 py-2 rounded-lg transition-all duration-200"
    
    # 현재 경로 확인 (approvals와 admin 경로 특별 처리)
    is_current = if path == approvals_path
                   request.path.start_with?('/approvals')
                 elsif path == admin_root_path
                   request.path.start_with?('/admin')
                 else
                   current_page?(path)
                 end
    
    if is_current
      "#{base_classes} bg-gray-100 text-gray-900"
    else
      "#{base_classes} text-gray-700 hover:bg-gray-50"
    end
  end
end
