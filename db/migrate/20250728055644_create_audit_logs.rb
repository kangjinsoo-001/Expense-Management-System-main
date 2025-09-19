class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.references :auditable, polymorphic: true, null: false
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.text :changed_from
      t.text :changed_to
      t.text :metadata

      t.timestamps
    end
  end
end
