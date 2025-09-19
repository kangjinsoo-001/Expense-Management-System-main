class CreateAttachmentRequirements < ActiveRecord::Migration[8.0]
  def change
    create_table :attachment_requirements do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :required, default: false, null: false
      t.text :file_types # JSON 형식으로 저장 (SQLite는 JSON 타입 지원)
      t.text :condition_expression
      t.integer :position, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :attachment_requirements, :position
    add_index :attachment_requirements, :active
  end
end
