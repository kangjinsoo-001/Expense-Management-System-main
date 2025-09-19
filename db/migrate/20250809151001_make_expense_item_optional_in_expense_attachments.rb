class MakeExpenseItemOptionalInExpenseAttachments < ActiveRecord::Migration[8.0]
  def change
    change_column_null :expense_attachments, :expense_item_id, true
  end
end
