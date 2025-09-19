class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.references :parent, foreign_key: { to_table: :organizations }
      t.references :manager, foreign_key: { to_table: :users }
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :organizations, :code, unique: true
    add_index :organizations, :deleted_at
  end
end
