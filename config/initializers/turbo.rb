# Turbo 전역 설정
Rails.application.config.to_prepare do
  # 기본적으로 모든 폼에서 Turbo를 비활성화
  Rails.application.config.action_view.form_with_generates_remote_forms = false
end