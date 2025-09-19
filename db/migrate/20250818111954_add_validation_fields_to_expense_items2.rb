class AddValidationFieldsToExpenseItems2 < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_items, :requires_user_confirmation, :boolean, default: false
    add_column :expense_items, :submission_blocked, :boolean, default: false
    add_column :expense_sheets, :ready_for_submission, :boolean, default: false
  end
end
