class CreateExpenseAttachments < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_attachments do |t|
      t.references :expense_item, null: false, foreign_key: true
      t.string :file_name
      t.string :file_type
      t.integer :file_size
      t.string :status, default: 'pending'
      t.text :extracted_text
      t.json :metadata, default: {}

      t.timestamps
    end
    
    add_index :expense_attachments, :status
    # SQLite doesn't support gin index for json columns
  end
end
