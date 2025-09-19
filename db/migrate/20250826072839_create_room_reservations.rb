class CreateRoomReservations < ActiveRecord::Migration[8.0]
  def change
    create_table :room_reservations do |t|
      t.references :room, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :reservation_date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.text :purpose, null: false
      t.references :recurring_reservation_rule, foreign_key: true

      t.timestamps
    end
    
    add_index :room_reservations, [:room_id, :reservation_date]
    add_index :room_reservations, [:user_id, :reservation_date]
    add_index :room_reservations, :reservation_date
  end
end
