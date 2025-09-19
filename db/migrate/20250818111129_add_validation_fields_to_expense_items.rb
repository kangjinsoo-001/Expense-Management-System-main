class AddValidationFieldsToExpenseItems < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_items, :validation_status, :string, default: 'pending'
    add_column :expense_items, :validation_message, :text
    add_column :expense_items, :validated_at, :datetime
    
    add_index :expense_items, :validation_status
  end
end
