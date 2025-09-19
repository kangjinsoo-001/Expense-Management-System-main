class AddAttachmentRequiredToExpenseCodes < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_codes, :attachment_required, :boolean, default: false, null: false
  end
end
