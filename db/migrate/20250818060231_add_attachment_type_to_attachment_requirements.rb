class AddAttachmentTypeToAttachmentRequirements < ActiveRecord::Migration[8.0]
  def change
    add_column :attachment_requirements, :attachment_type, :string, default: 'expense_sheet', null: false
    add_index :attachment_requirements, :attachment_type
    
    # 기존 데이터 업데이트 (이미 존재하는 경우)
    reversible do |dir|
      dir.up do
        AttachmentRequirement.update_all(attachment_type: 'expense_sheet')
      end
    end
  end
end
