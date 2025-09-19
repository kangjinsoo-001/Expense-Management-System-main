class AddBudgetFieldsToExpenseItems < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_items, :is_budget, :boolean, default: false, null: false
    add_column :expense_items, :budget_amount, :decimal, precision: 10, scale: 2
    add_column :expense_items, :actual_amount, :decimal, precision: 10, scale: 2
    add_column :expense_items, :budget_exceeded, :boolean, default: false
    add_column :expense_items, :excess_reason, :text
    add_column :expense_items, :budget_approved_at, :datetime
    add_column :expense_items, :actual_approved_at, :datetime
    
    # 인덱스 추가
    add_index :expense_items, :is_budget
    add_index :expense_items, :budget_exceeded
  end
end
