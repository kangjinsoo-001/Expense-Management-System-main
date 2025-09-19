class CreateRecurringReservationRules < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_reservation_rules do |t|
      t.string :frequency
      t.string :days_of_week
      t.date :end_date
      t.integer :max_occurrences

      t.timestamps
    end
  end
end
