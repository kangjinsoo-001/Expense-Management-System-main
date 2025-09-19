class CreateExpenseValidationHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_validation_histories do |t|
      t.references :expense_sheet, null: false, foreign_key: true
      t.references :validated_by, null: false, foreign_key: { to_table: :users }
      t.text :validation_summary
      t.boolean :all_valid, default: false
      t.json :validation_details, default: {}
      t.json :issues_found, default: []
      t.json :recommendations, default: []
      t.json :attachment_data, default: {}  # 검증 시점의 첨부파일 스냅샷
      t.json :expense_items_data, default: []  # 검증 시점의 경비 항목 스냅샷
      
      t.timestamps
    end
    
    add_index :expense_validation_histories, [:expense_sheet_id, :created_at], 
              name: 'index_validation_histories_on_sheet_and_created'
  end
end