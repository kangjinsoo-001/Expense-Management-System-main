class CreateExpenseSheets < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_sheets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :month, null: false
      t.string :status, default: 'draft', null: false # draft, submitted, approved, rejected
      t.decimal :total_amount, precision: 10, scale: 2, default: 0
      t.datetime :submitted_at
      t.datetime :approved_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.text :remarks
      t.text :rejection_reason

      t.timestamps
    end

    add_index :expense_sheets, [:user_id, :year, :month], unique: true
    add_index :expense_sheets, :status
  end
end
