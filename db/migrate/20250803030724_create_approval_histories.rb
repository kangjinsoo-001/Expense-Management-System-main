class CreateApprovalHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :approval_histories do |t|
      t.references :approval_request, null: false, foreign_key: true
      t.references :approver, null: false, foreign_key: { to_table: :users }
      t.integer :step_order, null: false
      t.string :role, null: false
      t.string :action, null: false
      t.text :comment
      t.datetime :approved_at, null: false

      t.timestamps
    end
    
    add_index :approval_histories, [:approval_request_id, :approver_id, :step_order], 
              unique: true, name: 'idx_unique_approval_history'
    add_index :approval_histories, :approved_at
    add_index :approval_histories, :action
  end
end
