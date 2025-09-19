class AddPurposeAndContentToRequestForms < ActiveRecord::Migration[8.0]
  def change
    add_column :request_forms, :purpose, :text
    add_column :request_forms, :content, :text
  end
end
