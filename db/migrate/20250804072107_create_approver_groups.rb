class CreateApproverGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :approver_groups do |t|
      t.string :name, null: false
      t.text :description
      t.integer :priority, null: false, default: 5
      t.boolean :is_active, null: false, default: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    
    add_index :approver_groups, :priority
    add_index :approver_groups, :name, unique: true
    add_index :approver_groups, :is_active
  end
end
