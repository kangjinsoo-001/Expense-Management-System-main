class CreateRequestForms < ActiveRecord::Migration[8.0]
  def change
    create_table :request_forms do |t|
      t.references :request_template, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :request_number
      t.string :title
      t.text :form_data
      t.string :status, default: 'draft', null: false
      t.references :approval_line, foreign_key: true
      t.datetime :submitted_at
      t.datetime :approved_at
      t.datetime :rejected_at
      t.text :rejection_reason
      t.boolean :is_draft, default: false, null: false
      t.text :draft_data

      t.timestamps
    end
    
    add_index :request_forms, :request_number, unique: true
    add_index :request_forms, :status
    add_index :request_forms, :is_draft
    add_index :request_forms, :submitted_at
  end
end
