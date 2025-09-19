class CreateExpenseItems < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_items do |t|
      t.references :expense_sheet, null: false, foreign_key: true
      t.references :expense_code, null: false, foreign_key: true
      t.references :cost_center, null: false, foreign_key: true
      t.date :expense_date, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :description, null: false
      t.json :custom_fields # 경비 코드별 추가 필드 저장
      t.json :validation_errors # 검증 오류 저장
      t.boolean :is_valid, default: false
      t.text :remarks
      
      # 영수증 정보
      t.string :receipt_number
      t.string :vendor_name
      t.string :vendor_tax_id
      
      t.timestamps
    end

    add_index :expense_items, :expense_date
    add_index :expense_items, :is_valid
  end
end
