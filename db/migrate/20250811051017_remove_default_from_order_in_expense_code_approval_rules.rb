class RemoveDefaultFromOrderInExpenseCodeApprovalRules < ActiveRecord::Migration[8.0]
  def change
    change_column_default :expense_code_approval_rules, :order, from: 1, to: nil
  end
end
