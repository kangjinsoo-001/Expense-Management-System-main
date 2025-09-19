class CreateRequestTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :request_templates do |t|
      t.references :request_category, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.text :description
      t.text :instructions
      t.integer :display_order, default: 0
      t.boolean :is_active, default: true, null: false
      t.boolean :attachment_required, default: false, null: false
      t.boolean :auto_numbering, default: true, null: false
      t.integer :version, default: 1, null: false

      t.timestamps
    end
    
    add_index :request_templates, :code, unique: true
    add_index :request_templates, [:request_category_id, :name], unique: true
    add_index :request_templates, :display_order
    add_index :request_templates, :is_active
  end
end
