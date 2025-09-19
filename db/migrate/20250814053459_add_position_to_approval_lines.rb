class AddPositionToApprovalLines < ActiveRecord::Migration[8.0]
  def change
    add_column :approval_lines, :position, :integer
    add_index :approval_lines, [:user_id, :position]
    
    # 기존 데이터에 position 값 설정
    reversible do |dir|
      dir.up do
        User.find_each do |user|
          user.approval_lines.order(:created_at).each_with_index do |line, index|
            line.update_column(:position, index + 1)
          end
        end
      end
    end
  end
end
