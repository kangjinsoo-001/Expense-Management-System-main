class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.string :employee_id, null: false
      t.integer :role, default: 0, null: false

      t.timestamps
    end
    
    add_index :users, :email, unique: true
    add_index :users, :employee_id, unique: true
  end
end
