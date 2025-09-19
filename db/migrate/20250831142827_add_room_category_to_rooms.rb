class AddRoomCategoryToRooms < ActiveRecord::Migration[8.0]
  def change
    add_reference :rooms, :room_category, null: true, foreign_key: true
    
    # 기존 category 필드는 데이터 마이그레이션 후 삭제 예정
    # remove_column :rooms, :category, :string
  end
end
