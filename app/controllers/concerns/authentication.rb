module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_login
    helper_method :current_user, :logged_in?
  end

  def current_user
    # 로컬 개발 환경에서 캐싱 문제 방지를 위해 매번 다시 확인
    if Rails.env.development?
      @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
    else
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    end
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    unless logged_in?
      redirect_to login_path, alert: "로그인이 필요합니다."
    end
  end

  def redirect_if_logged_in
    if logged_in?
      redirect_to root_path, notice: "이미 로그인되어 있습니다."
    end
  end
end