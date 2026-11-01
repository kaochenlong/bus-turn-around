# The district of each stop and the districts of each route day, as defined
# by the stop-districts spec: a stop's district is the county and town of its
# stop location read from the stop district snapshot, NULL for a stop without
# one; a route day's district rows count the page route's stop locations in
# each district, their share of all its stop locations and whether that share
# reaches the threshold of analysis/params.sql; stop_districts_day is the day
# of the snapshot used. Days loaded before this have none of them until they
# are loaded again; nothing is filled in here, because the raw files live
# under the data root.
class CreateRouteDayDistricts < ActiveRecord::Migration[8.1]
  def change
    create_table :route_day_districts do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :county, null: false
      t.string :town, null: false
      t.integer :n_locations, null: false
      t.float :share, null: false
      t.boolean :qualifies, null: false
      t.index [ :route_day_id, :county, :town ], unique: true
    end
    add_column :route_day_stops, :district, :string
    add_column :route_days, :stop_districts_day, :date
  end
end
