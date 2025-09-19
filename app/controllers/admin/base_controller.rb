class Admin::BaseController < ApplicationController
  before_action :require_admin!
  layout 'admin'

  private

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "권한이 없습니다."
    end
  end
end