# The rest windows and the continuous driving stretches of each route day, as
# defined by the layover-metrics spec: one row per window of the four-hour rule
# and of the six-hour exception, and one per stretch, deleted with the route
# day. rest_windows_loaded tells a day without any window from a day stored
# before these tables existed, which stays false until it is loaded again;
# nothing is filled in here, because the raw files live under the data root.
class CreateRouteDayRestWindows < ActiveRecord::Migration[8.1]
  def change
    create_table :route_day_rest_windows do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :bus_id, null: false
      t.string :rule, null: false
      t.timestamptz :start_time, null: false
      t.timestamptz :end_time, null: false
      t.integer :n_trips, null: false
      t.float :credit_minutes, null: false
      t.float :longest_layover_minutes, null: false
      t.boolean :flagged, null: false
      t.boolean :over_daily_driving, null: false
      t.index [ :route_day_id, :rule, :bus_id, :start_time ], unique: true, name: "index_route_day_rest_windows_on_day_rule_bus_start"
      t.check_constraint "rule IN ('four_hours', 'six_hours')", name: "route_day_rest_windows_rule"
    end
    create_table :route_day_driving_stretches do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :bus_id, null: false
      t.timestamptz :start_time, null: false
      t.timestamptz :end_time, null: false
      t.integer :n_trips, null: false
      t.index [ :route_day_id, :bus_id, :start_time ], unique: true, name: "index_route_day_driving_stretches_on_day_bus_start"
    end
    add_column :route_days, :rest_windows_loaded, :boolean, null: false, default: false
  end
end
