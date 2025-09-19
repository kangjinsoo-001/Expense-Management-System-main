class Admin::GeminiMetricsController < ApplicationController
  before_action :require_admin
  
  def index
    @metrics = GeminiMetricsService.instance.current_metrics
    
    respond_to do |format|
      format.html
      format.json { render json: @metrics }
    end
  end
  
  def reset
    GeminiMetricsService.instance.reset_metrics
    redirect_to admin_gemini_metrics_path, notice: 'Gemini API 메트릭이 초기화되었습니다.'
  end
  
  private
  
  def require_admin
    # 관리자 권한 체크 (추후 구현)
    # redirect_to root_path unless current_user&.admin?
  end
end