# Rows loaded before AddMemberRouteColumnsToDerivedTables belong to their
# route day's route. Rolling back leaves the values in place; rolling back the
# previous migration then drops them with the columns.
class BackfillRouteIdOnDerivedRows < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE route_day_stops s SET route_id = d.route_id FROM route_days d WHERE d.id = s.route_day_id AND s.route_id IS NULL"
    execute "UPDATE trips t SET route_id = d.route_id FROM route_days d WHERE d.id = t.route_day_id AND t.route_id IS NULL"
  end

  def down; end
end
