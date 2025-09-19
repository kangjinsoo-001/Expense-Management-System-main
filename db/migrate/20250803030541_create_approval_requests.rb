class CreateApprovalRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :approval_requests do |t|
      t.references :expense_item, null: false, foreign_key: true, index: { unique: true }
      t.references :approval_line, null: false, foreign_key: true
      t.integer :current_step, null: false, default: 1
      t.string :status, null: false, default: 'pending'

      t.timestamps
    end
    
    add_index :approval_requests, :status
  end
end
