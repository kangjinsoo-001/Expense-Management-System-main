class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Turbo Streams를 위한 헬퍼 메서드
  helper_method :dom_id
  
  # 승인 대기 건수를 위한 헬퍼 메서드
  helper_method :pending_approval_count
  
  def pending_approval_count
    return 0 unless logged_in?
    @pending_approval_count ||= ApprovalRequest.for_approver(current_user).count
  end
  
  # redirect_to를 오버라이딩하여 Turbo와 호환되도록 함
  def redirect_to(options = {}, response_options = {})
    # Turbo 요청이거나 일반 HTML 요청인 경우 자동으로 303 상태 코드 설정
    # 이미 status가 명시된 경우는 그대로 유지
    if request.format.turbo_stream? || request.format.html?
      response_options[:status] ||= :see_other
    end
    
    super(options, response_options)
  end
  
  private
  
  def dom_id(record, prefix = nil)
    ActionView::RecordIdentifier.dom_id(record, prefix)
  end
end
