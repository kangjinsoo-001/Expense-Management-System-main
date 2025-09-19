module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :can_manage_organization?
  end

  private

  def authorize_admin!
    unless current_user&.admin?
      flash[:alert] = "관리자 권한이 필요합니다."
      redirect_to root_path
    end
  end

  def authorize_organization_manager!(organization)
    unless can_manage_organization?(organization)
      flash[:alert] = "해당 조직을 관리할 권한이 없습니다."
      redirect_to organizations_path
    end
  end

  def can_manage_organization?(organization)
    return false unless current_user
    current_user.can_manage_organization?(organization)
  end
end