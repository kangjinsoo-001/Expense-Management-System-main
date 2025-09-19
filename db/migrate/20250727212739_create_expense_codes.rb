class CreateExpenseCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_codes do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.decimal :limit_amount, precision: 10, scale: 2
      t.json :validation_rules, default: {}
      t.boolean :active, default: true
      t.references :organization, foreign_key: true

      t.timestamps
    end
    
    add_index :expense_codes, :code, unique: true
  end
end
