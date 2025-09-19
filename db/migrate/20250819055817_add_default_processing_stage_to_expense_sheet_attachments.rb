class AddDefaultProcessingStageToExpenseSheetAttachments < ActiveRecord::Migration[8.0]
  def change
    change_column_default :expense_sheet_attachments, :processing_stage, from: nil, to: 'pending'
  end
end
