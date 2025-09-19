class AddUsersCountToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :users_count, :integer, default: 0, null: false
    
    # 기존 데이터의 카운트 업데이트
    reversible do |dir|
      dir.up do
        Organization.find_each do |organization|
          Organization.reset_counters(organization.id, :users)
        end
      end
    end
  end
end
