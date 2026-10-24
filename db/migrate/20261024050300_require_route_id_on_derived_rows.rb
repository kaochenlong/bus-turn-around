# route_id becomes required on stops and trips, and a route day's stops are
# unique per route Id, direction and sequence number, so a member route's stop
# list can sit next to the page route's.
class RequireRouteIdOnDerivedRows < ActiveRecord::Migration[8.1]
  def change
    change_column_null :route_day_stops, :route_id, false
    change_column_null :trips, :route_id, false
    remove_index :route_day_stops, [ :route_day_id, :go_back, :seq ], unique: true
    add_index :route_day_stops, [ :route_day_id, :route_id, :go_back, :seq ], unique: true, name: "index_route_day_stops_on_route_day_route_direction_seq"
  end
end
