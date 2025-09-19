class CreateExpenseSheetApprovalRules < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_sheet_approval_rules do |t|
      t.references :organization, foreign_key: true
      t.references :approver_group, null: false, foreign_key: true
      
      # 제출자 조건
      t.references :submitter_group, foreign_key: { to_table: :approver_groups }
      t.string :submitter_condition  # 예: "제출자가 보직자일 때"
      
      # 일반 조건
      t.string :condition  # "#총금액 > 1000000"
      t.string :rule_type  # 'total_amount', 'submitter_based', 'item_count', 'complex'
      
      t.integer :order
      t.boolean :is_active, default: true
      t.json :metadata, default: {}
      
      t.timestamps
    end
    
    add_index :expense_sheet_approval_rules, [:organization_id, :is_active]
    add_index :expense_sheet_approval_rules, :order
  end
end
