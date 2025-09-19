class AddCategoryToRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :rooms, :category, :string
    add_index :rooms, :category
    
    # 기존 데이터 마이그레이션
    reversible do |dir|
      dir.up do
        Room.reset_column_information
        Room.find_each do |room|
          if room.name.include?("(판교)")
            room.update_column(:category, "판교")
          elsif room.name.include?("(강남)")
            room.update_column(:category, "강남")
          elsif room.name.include?("(서초)")
            room.update_column(:category, "서초")
          end
        end
      end
    end
  end
end
