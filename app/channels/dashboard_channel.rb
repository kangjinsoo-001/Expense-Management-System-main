class DashboardChannel < ApplicationCable::Channel
  def subscribed
    if current_user&.admin?
      stream_from "admin_dashboard"
      stream_from "admin_dashboard_#{current_user.id}"
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
