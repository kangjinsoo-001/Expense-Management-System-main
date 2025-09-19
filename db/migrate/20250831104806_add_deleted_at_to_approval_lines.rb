class AddDeletedAtToApprovalLines < ActiveRecord::Migration[8.0]
  def change
    add_column :approval_lines, :deleted_at, :datetime
    add_index :approval_lines, :deleted_at
  end
end
