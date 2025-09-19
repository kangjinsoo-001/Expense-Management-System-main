class CreateApproverGroupMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :approver_group_members do |t|
      t.references :approver_group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :added_by, null: false, foreign_key: { to_table: :users }
      t.datetime :added_at, null: false

      t.timestamps
    end
    
    # 같은 그룹에 동일 사용자 중복 방지
    add_index :approver_group_members, [:approver_group_id, :user_id], unique: true,
              name: 'index_approver_group_members_on_group_and_user'
  end
end
