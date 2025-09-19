class RemoveIconAndColorFromRequestCategories < ActiveRecord::Migration[8.0]
  def change
    remove_column :request_categories, :icon, :string
    remove_column :request_categories, :color, :string
  end
end
