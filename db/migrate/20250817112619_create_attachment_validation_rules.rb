class CreateAttachmentValidationRules < ActiveRecord::Migration[8.0]
  def change
    create_table :attachment_validation_rules do |t|
      t.references :attachment_requirement, null: false, foreign_key: true
      t.string :rule_type, null: false # required, amount_match, order_match, custom
      t.text :prompt_text, null: false
      t.string :severity, null: false, default: 'warning' # pass, warning, error
      t.integer :position, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :attachment_validation_rules, :rule_type
    add_index :attachment_validation_rules, :severity
    add_index :attachment_validation_rules, :position
    add_index :attachment_validation_rules, :active
  end
end
