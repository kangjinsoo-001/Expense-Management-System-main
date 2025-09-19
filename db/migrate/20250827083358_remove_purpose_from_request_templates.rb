class RemovePurposeFromRequestTemplates < ActiveRecord::Migration[8.0]
  def change
    remove_column :request_templates, :purpose, :text
    remove_column :request_templates, :approval_level, :integer
    remove_column :request_templates, :max_approval_level, :integer
  end
end
