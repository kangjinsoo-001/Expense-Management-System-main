class AddCancelledAtToApprovalRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :approval_requests, :cancelled_at, :datetime
    add_column :approval_requests, :completed_at, :datetime
  end
end
