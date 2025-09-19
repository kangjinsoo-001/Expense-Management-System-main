# Turbo Drive 캐싱 문제를 해결하기 위한 concern
module TurboCacheControl
  extend ActiveSupport::Concern

  private

  # Turbo Drive가 캐시를 무시하고 페이지를 다시 로드하도록 강제
  def force_turbo_reload
    response.set_header("Turbo-Visit-Control", "reload")
  end

  # 플래시 메시지와 함께 리다이렉트 (Turbo 캐시 문제 해결)
  def redirect_with_turbo_reload(path, options = {})
    force_turbo_reload
    redirect_to path, options
  end
end