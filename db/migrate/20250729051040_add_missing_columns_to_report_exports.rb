class AddMissingColumnsToReportExports < ActiveRecord::Migration[8.0]
  def change
    add_column :report_exports, :file_size, :integer
    add_column :report_exports, :error_message, :text
  end
end
