# A route page can count member routes with its page route
# (02-route-307-page), so the stored rows say which route Id they belong to:
# every stop and trip gets route_id, every stop its stopLocationId, and the
# route day the names of its member routes. The columns start empty; the next
# two migrations fill route_id from the route day and make it required.
class AddMemberRouteColumnsToDerivedTables < ActiveRecord::Migration[8.1]
  def change
    change_table :route_day_stops, bulk: true do |t|
      t.integer :route_id
      t.integer :stop_location_id
    end
    add_column :trips, :route_id, :integer
    add_column :route_days, :member_names, :jsonb, null: false, default: {}
  end
end
