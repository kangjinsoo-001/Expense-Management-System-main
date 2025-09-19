class CreateRoomCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :room_categories do |t|
      t.string :name, null: false
      t.text :description
      t.integer :display_order, default: 0
      t.boolean :is_active, default: true

      t.timestamps
    end
    
    add_index :room_categories, :name, unique: true
    add_index :room_categories, :display_order
  end
end
