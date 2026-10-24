# The depots of each route day: per depot the vehicles of the day's trips
# belong to, its StationID, the operator and station names of the day's
# GetProvider.gz (empty strings when the snapshot had none) and the numbers of
# vehicles and trips, deleted with the route day. Days loaded before this have
# no depots until they are loaded again; nothing is filled in here, because
# the raw files live under the data root.
class CreateRouteDayDepots < ActiveRecord::Migration[8.1]
  def change
    create_table :route_day_depots do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :station_id, null: false
      t.string :provider_name, null: false
      t.string :station_name, null: false
      t.integer :n_buses, null: false
      t.integer :n_trips, null: false
      t.index [ :route_day_id, :station_id ], unique: true
    end
  end
end
