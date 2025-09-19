class AddExpenseAttachmentsCountToExpenseItems < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_items, :expense_attachments_count, :integer, default: 0, null: false
    
    # 기존 데이터의 카운터 캐시 업데이트
    ExpenseItem.find_each do |item|
      ExpenseItem.reset_counters(item.id, :expense_attachments)
    end
  end
end
