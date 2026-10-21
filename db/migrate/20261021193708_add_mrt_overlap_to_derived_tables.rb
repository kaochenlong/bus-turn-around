# Each stop's coordinates and nearest Taipei MRT entrance, and the entrance
# snapshot a route day was computed with. Days loaded before this stay empty
# until they are loaded again; the route page says so instead of showing 0%.
class AddMrtOverlapToDerivedTables < ActiveRecord::Migration[8.1]
  def change
    change_table :route_day_stops, bulk: true do |t|
      t.float :latitude
      t.float :longitude
      t.string :nearest_exit_name
      t.float :nearest_exit_meters
    end
    add_column :route_days, :mrt_exits_day, :date
  end
end
