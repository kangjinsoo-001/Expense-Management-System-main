class CreateApprovalLines < ActiveRecord::Migration[8.0]
  def change
    create_table :approval_lines do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end
    
    add_index :approval_lines, [:user_id, :name], unique: true
  end
end
