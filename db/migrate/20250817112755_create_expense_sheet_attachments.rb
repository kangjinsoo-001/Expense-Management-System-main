class CreateExpenseSheetAttachments < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_sheet_attachments do |t|
      t.references :expense_sheet, null: false, foreign_key: true
      t.references :attachment_requirement, foreign_key: true # null 허용 (자유 첨부 가능)
      t.text :extracted_text
      t.text :analysis_result # JSON 형식으로 저장
      t.text :validation_result # JSON 형식으로 저장
      t.string :status, default: 'pending', null: false # pending, analyzing, completed, failed

      t.timestamps
    end

    add_index :expense_sheet_attachments, :status
    add_index :expense_sheet_attachments, [:expense_sheet_id, :attachment_requirement_id], 
              name: 'index_expense_sheet_attachments_on_sheet_and_requirement'
  end
end
