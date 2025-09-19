class CreateExpenseCodeApprovalRules < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_code_approval_rules do |t|
      t.references :expense_code, null: false, foreign_key: true
      t.string :condition, null: false
      t.references :approver_group, null: false, foreign_key: true
      t.integer :order, null: false, default: 1
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end
    
    add_index :expense_code_approval_rules, [:expense_code_id, :order]
    add_index :expense_code_approval_rules, :is_active
  end
end
