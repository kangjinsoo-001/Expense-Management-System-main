class AddFieldsToRequestTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :request_templates, :purpose, :text
    add_column :request_templates, :approval_level, :integer, default: 1
    add_column :request_templates, :max_approval_level, :integer, default: 3
    add_column :request_templates, :required_fields, :text
    add_column :request_templates, :optional_fields, :text
  end
end
