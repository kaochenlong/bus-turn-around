# The derived tables: per-trip results of one route and one Taipei day,
# written by bin/rails derived:load from the raw files. A day is replaced as a
# whole, so every table hangs off route_days and goes with it on delete.
# Times are Taipei times stored with their offset.
class CreateDerivedTables < ActiveRecord::Migration[8.1]
  def change
    create_table :route_days do |t|
      t.integer :route_id, null: false
      t.date :day, null: false
      t.string :route_name, null: false
      t.string :departure, null: false
      t.string :destination, null: false
      t.date :static_day, null: false
      t.timestamptz :loaded_at, null: false
      t.index [ :route_id, :day ], unique: true
    end

    create_table :route_day_stops do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :go_back, null: false
      t.integer :seq, null: false
      t.string :stop_name, null: false
      t.index [ :route_day_id, :go_back, :seq ], unique: true
    end

    create_table :trips do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :bus_id, null: false
      t.integer :path_attribute_id, null: false
      t.integer :go_back, null: false
      t.string :band, null: false
      t.timestamptz :start_time, null: false
      t.timestamptz :end_time, null: false
      t.integer :first_seq, null: false
      t.integer :last_seq, null: false
      t.integer :n_events, null: false
      t.integer :n_stops_observed, null: false
      t.string :completeness, null: false
      t.boolean :start_from_arrival, null: false
      t.boolean :end_from_departure, null: false
      t.index [ :route_day_id, :bus_id, :start_time ], unique: true
    end

    create_table :layovers do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }
      t.string :bus_id, null: false
      t.integer :go_back, null: false
      t.timestamptz :end_time, null: false
      t.timestamptz :next_start_time, null: false
    end

    create_table :trip_stop_counts do |t|
      t.references :trip, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :seq, null: false
      t.integer :on_board, null: false
      t.index [ :trip_id, :seq ], unique: true
    end
  end
end
