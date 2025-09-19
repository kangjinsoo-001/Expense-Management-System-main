class CreateRequestFormAttachments < ActiveRecord::Migration[8.0]
  def change
    create_table :request_form_attachments do |t|
      t.references :request_form, null: false, foreign_key: true
      t.string :field_key
      t.string :file_name
      t.integer :file_size
      t.string :content_type
      t.text :description
      t.references :uploaded_by, null: false, foreign_key: true

      t.timestamps
    end
  end
end
