# The stop speeds of each trip: per trip and leg, the leg's first stop, the
# band of the time the vehicle reached it and the metres and seconds of its
# counted GPS pairs, deleted with the trip; and each stop's position along the
# route shape of its direction, NULL for a stop without a position. Days
# loaded before this have neither until they are loaded again; nothing is
# filled in here, because the raw files live under the data root.
class CreateTripStopSpeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_stop_speeds do |t|
      t.references :trip, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :seq, null: false
      t.string :band, null: false
      t.float :meters, null: false
      t.integer :seconds, null: false
      t.index [ :trip_id, :seq ], unique: true
    end
    add_column :route_day_stops, :shape_meters, :float
  end
end
