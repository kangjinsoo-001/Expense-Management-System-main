class CreateReportExports < ActiveRecord::Migration[8.0]
  def change
    create_table :report_exports do |t|
      t.references :report_template, null: true, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :file_path
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :total_records

      t.timestamps
    end
  end
end
