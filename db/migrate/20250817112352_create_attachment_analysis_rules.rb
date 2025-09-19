class CreateAttachmentAnalysisRules < ActiveRecord::Migration[8.0]
  def change
    create_table :attachment_analysis_rules do |t|
      t.references :attachment_requirement, null: false, foreign_key: true
      t.text :prompt_text, null: false
      t.text :expected_fields # JSON 형식으로 저장
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :attachment_analysis_rules, :active
  end
end
