class CreateRequestCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :request_categories do |t|
      t.string :name, null: false
      t.text :description
      t.string :icon
      t.string :color
      t.integer :display_order, default: 0
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
    
    add_index :request_categories, :name, unique: true
    add_index :request_categories, :display_order
    add_index :request_categories, :is_active
  end
end
