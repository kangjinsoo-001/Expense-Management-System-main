class CreateReportTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :report_templates do |t|
      t.string :name
      t.text :description
      t.text :filter_config
      t.text :columns_config
      t.string :export_format
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
