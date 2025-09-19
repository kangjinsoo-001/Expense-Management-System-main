class AddGeneratedDescriptionToExpenseItems < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_items, :generated_description, :text
  end
end
