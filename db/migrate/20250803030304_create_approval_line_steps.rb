class CreateApprovalLineSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :approval_line_steps do |t|
      t.references :approval_line, null: false, foreign_key: true
      t.references :approver, null: false, foreign_key: { to_table: :users }
      t.integer :step_order, null: false
      t.string :role, null: false
      t.string :approval_type

      t.timestamps
    end
    
    add_index :approval_line_steps, [:approval_line_id, :step_order]
    add_index :approval_line_steps, [:approval_line_id, :approver_id, :step_order], 
              unique: true, name: 'idx_unique_approver_per_step'
  end
end
