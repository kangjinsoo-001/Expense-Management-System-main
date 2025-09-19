class RemoveFloorFromRooms < ActiveRecord::Migration[8.0]
  def change
    remove_column :rooms, :floor, :integer
  end
end
