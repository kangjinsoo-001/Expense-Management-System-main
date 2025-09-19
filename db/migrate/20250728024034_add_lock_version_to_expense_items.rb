class AddLockVersionToExpenseItems < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_items, :lock_version, :integer, default: 0, null: false
    add_index :expense_items, :lock_version
  end
end
