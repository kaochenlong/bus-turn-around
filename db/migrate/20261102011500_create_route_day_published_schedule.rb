# The published schedule of each route day, as defined by the published-schedule
# spec: one row per period and one per scheduled departure of every date value
# in the day's static snapshot, deleted with the route day. The rows of a route
# Id repeat across its sub-routes as the snapshot has them; whoever reads them
# removes the repeats, so nothing here is unique. published_schedule_day is the
# day of the snapshot read. It stays empty on a day stored before these tables
# existed, until that day is loaded again; nothing is filled in here, because
# the raw files live under the data root.
class CreateRouteDayPublishedSchedule < ActiveRecord::Migration[8.1]
  def change
    create_table :route_day_published_headways do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :route_id, null: false
      t.integer :path_attribute_id, null: false
      t.integer :date_value, null: false
      t.integer :start_minute, null: false
      t.integer :end_minute, null: false
      t.integer :low_minutes, null: false
      t.integer :high_minutes, null: false
      t.index [ :route_day_id, :route_id, :date_value ], name: "index_route_day_published_headways_on_day_route_value"
    end
    create_table :route_day_published_departures do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :route_id, null: false
      t.integer :path_attribute_id, null: false
      t.integer :date_value, null: false
      t.integer :minute, null: false
      t.index [ :route_day_id, :route_id, :date_value ], name: "index_route_day_published_departures_on_day_route_value"
    end
    add_column :route_days, :published_schedule_day, :date
  end
end
