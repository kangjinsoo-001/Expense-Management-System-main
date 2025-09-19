class CreateTransactionMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :transaction_matches do |t|
      t.references :pdf_analysis_result, null: false, foreign_key: true
      t.references :expense_item, null: false, foreign_key: true
      t.json :transaction_data
      t.decimal :confidence
      t.string :match_type
      t.boolean :is_confirmed, default: false

      t.timestamps
    end
    add_index :transaction_matches, :is_confirmed
    add_index :transaction_matches, :match_type
    add_index :transaction_matches, [:pdf_analysis_result_id, :expense_item_id], name: 'index_transaction_matches_on_pdf_and_expense_item'
  end
end
