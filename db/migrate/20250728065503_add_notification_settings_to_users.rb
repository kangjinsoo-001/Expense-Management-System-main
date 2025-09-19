class AddNotificationSettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email_notifications_enabled, :boolean, default: true
    add_column :users, :teams_notifications_enabled, :boolean, default: false
  end
end
