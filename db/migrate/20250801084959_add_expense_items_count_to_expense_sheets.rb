class AddExpenseItemsCountToExpenseSheets < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_sheets, :expense_items_count, :integer, default: 0, null: false
    
    # 기존 데이터의 카운트 업데이트
    reversible do |dir|
      dir.up do
        ExpenseSheet.find_each do |expense_sheet|
          ExpenseSheet.reset_counters(expense_sheet.id, :expense_items)
        end
      end
    end
  end
end
