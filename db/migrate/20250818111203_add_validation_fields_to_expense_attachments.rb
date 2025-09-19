class AddValidationFieldsToExpenseAttachments < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_attachments, :validation_result, :jsonb, default: {}
    add_column :expense_attachments, :validation_passed, :boolean, default: false
    
    add_index :expense_attachments, :validation_passed
  end
end
