class AddDraftFieldsToExpenseItems < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_items, :is_draft, :boolean, default: false, null: false
    add_column :expense_items, :draft_data, :json, default: {}
    add_column :expense_items, :last_saved_at, :datetime
    
    add_index :expense_items, :is_draft
    add_index :expense_items, [:expense_sheet_id, :is_draft]
  end
end
