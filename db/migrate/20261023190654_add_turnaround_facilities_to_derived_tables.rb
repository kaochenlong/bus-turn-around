# The turnaround facilities of each route day: per end, its location and
# check numbers, the public toilets within 500 metres of the location, and the
# standstill cells for a map, all deleted with the route day. A route day also
# records which toilet snapshot it used. Days loaded before this have no end
# rows until they are loaded again; nothing is filled in here, because the
# GPS files and the snapshot live under the data root.
class AddTurnaroundFacilitiesToDerivedTables < ActiveRecord::Migration[8.1]
  def change
    add_column :route_days, :public_toilets_day, :date

    create_table :route_day_ends do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :go_back, null: false
      t.integer :end_seq, null: false
      t.string :end_stop_name, null: false
      t.float :end_latitude
      t.float :end_longitude
      t.string :location_source
      t.float :latitude
      t.float :longitude
      t.integer :n_layovers, null: false
      t.integer :n_located_layovers
      t.integer :n_standstill_records, null: false
      t.float :end_stop_meters
      t.index [ :route_day_id, :go_back ], unique: true
    end

    create_table :route_day_end_toilets do |t|
      t.references :route_day_end, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :category
      t.string :address
      t.float :latitude, null: false
      t.float :longitude, null: false
      t.float :meters, null: false
    end

    create_table :route_day_end_cells do |t|
      t.references :route_day_end, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.float :cell_latitude, null: false
      t.float :cell_longitude, null: false
      t.integer :n_records, null: false
      t.integer :n_buses, null: false
      t.integer :n_layovers, null: false
      t.index [ :route_day_end_id, :cell_latitude, :cell_longitude ], unique: true
    end
  end
end
