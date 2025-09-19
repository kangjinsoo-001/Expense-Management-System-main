class AddCostCenterToExpenseSheets < ActiveRecord::Migration[8.0]
  def change
    add_reference :expense_sheets, :cost_center, null: true, foreign_key: true
  end
end
