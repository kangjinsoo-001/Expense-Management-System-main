class CreatePdfAnalysisResults < ActiveRecord::Migration[8.0]
  def change
    create_table :pdf_analysis_results do |t|
      t.references :expense_sheet, null: false, foreign_key: true
      t.string :attachment_id
      t.text :extracted_text
      t.json :analysis_data
      t.string :card_type
      t.decimal :total_amount
      t.json :detected_dates
      t.json :detected_amounts

      t.timestamps
    end
    
    add_index :pdf_analysis_results, :attachment_id
    add_index :pdf_analysis_results, :card_type
  end
end
