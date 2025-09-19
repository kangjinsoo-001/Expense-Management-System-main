class AddAiFieldsToExpenseAttachments < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_attachments, :summary_data, :text
    add_column :expense_attachments, :receipt_type, :string
    add_column :expense_attachments, :processing_stage, :string, default: 'pending'
    add_column :expense_attachments, :ai_processed, :boolean, default: false
    add_column :expense_attachments, :ai_processed_at, :datetime
    
    # 인덱스 추가
    add_index :expense_attachments, :receipt_type
    add_index :expense_attachments, :processing_stage
    add_index :expense_attachments, :ai_processed
  end
end
