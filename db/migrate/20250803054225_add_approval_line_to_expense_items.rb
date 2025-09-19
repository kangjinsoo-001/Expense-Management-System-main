class AddApprovalLineToExpenseItems < ActiveRecord::Migration[8.0]
  def change
    add_reference :expense_items, :approval_line, null: true, foreign_key: true
  end
end
