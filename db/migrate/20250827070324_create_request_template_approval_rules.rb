class CreateRequestTemplateApprovalRules < ActiveRecord::Migration[8.0]
  def change
    create_table :request_template_approval_rules do |t|
      t.references :request_template, null: false, foreign_key: true
      t.references :approver_group, null: false, foreign_key: true
      t.text :condition
      t.integer :order
      t.boolean :is_active

      t.timestamps
    end
  end
end
