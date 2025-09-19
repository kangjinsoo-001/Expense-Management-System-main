class RemoveNotificationColumnsFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :email_notifications_enabled, :boolean
    remove_column :users, :teams_notifications_enabled, :boolean
  end
end
