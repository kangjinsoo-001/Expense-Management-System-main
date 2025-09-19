class RemovePurposeAndContentFromRequestForms < ActiveRecord::Migration[8.0]
  def change
    remove_column :request_forms, :purpose, :text
    remove_column :request_forms, :content, :text
  end
end
