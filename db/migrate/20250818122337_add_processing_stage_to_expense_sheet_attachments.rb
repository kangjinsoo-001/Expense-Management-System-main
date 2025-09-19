class AddProcessingStageToExpenseSheetAttachments < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_sheet_attachments, :processing_stage, :string, default: 'pending'
    add_index :expense_sheet_attachments, :processing_stage
  end
end
