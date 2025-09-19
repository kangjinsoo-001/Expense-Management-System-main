class AddDescriptionTemplateToExpenseCodes < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_codes, :description_template, :text
  end
end
