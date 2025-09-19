class AddFullValidationContextToExpenseValidationHistories < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_validation_histories, :full_validation_context, :json, default: {}
  end
end
