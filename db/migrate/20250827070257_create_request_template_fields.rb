class CreateRequestTemplateFields < ActiveRecord::Migration[8.0]
  def change
    create_table :request_template_fields do |t|
      t.references :request_template, null: false, foreign_key: true
      t.string :field_key, null: false
      t.string :field_label, null: false
      t.string :field_type, null: false
      t.text :field_options
      t.boolean :is_required, default: false, null: false
      t.text :validation_rules
      t.string :placeholder
      t.text :help_text
      t.integer :display_order, default: 0
      t.string :display_width, default: 'full'

      t.timestamps
    end
    
    add_index :request_template_fields, [:request_template_id, :field_key], unique: true, name: 'idx_template_field_key'
    add_index :request_template_fields, :display_order
  end
end
