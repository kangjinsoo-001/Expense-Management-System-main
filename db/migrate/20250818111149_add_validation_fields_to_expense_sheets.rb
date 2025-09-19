class AddValidationFieldsToExpenseSheets < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_sheets, :validation_result, :jsonb, default: {}
    add_column :expense_sheets, :validation_status, :string, default: 'pending'
    add_column :expense_sheets, :validated_at, :datetime
    
    add_index :expense_sheets, :validation_status
    add_index :expense_sheets, :validation_result, using: :gin
  end
end
