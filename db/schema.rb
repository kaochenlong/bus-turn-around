# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_24_062215) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "layovers", force: :cascade do |t|
    t.bigint "route_day_id", null: false
    t.string "bus_id", null: false
    t.integer "go_back", null: false
    t.timestamptz "end_time", null: false
    t.timestamptz "next_start_time", null: false
    t.index ["route_day_id"], name: "index_layovers_on_route_day_id"
  end

  create_table "route_day_depots", force: :cascade do |t|
    t.bigint "route_day_id", null: false
    t.integer "station_id", null: false
    t.string "provider_name", null: false
    t.string "station_name", null: false
    t.integer "n_buses", null: false
    t.integer "n_trips", null: false
    t.index ["route_day_id", "station_id"], name: "index_route_day_depots_on_route_day_id_and_station_id", unique: true
  end

  create_table "route_day_end_cells", force: :cascade do |t|
    t.bigint "route_day_end_id", null: false
    t.float "cell_latitude", null: false
    t.float "cell_longitude", null: false
    t.integer "n_records", null: false
    t.integer "n_buses", null: false
    t.integer "n_layovers", null: false
    t.index ["route_day_end_id", "cell_latitude", "cell_longitude"], name: "idx_on_route_day_end_id_cell_latitude_cell_longitud_cd42233ab5", unique: true
  end

  create_table "route_day_end_toilets", force: :cascade do |t|
    t.bigint "route_day_end_id", null: false
    t.string "name", null: false
    t.string "category"
    t.string "address"
    t.float "latitude", null: false
    t.float "longitude", null: false
    t.float "meters", null: false
    t.index ["route_day_end_id"], name: "index_route_day_end_toilets_on_route_day_end_id"
  end

  create_table "route_day_ends", force: :cascade do |t|
    t.bigint "route_day_id", null: false
    t.integer "go_back", null: false
    t.integer "end_seq", null: false
    t.string "end_stop_name", null: false
    t.float "end_latitude"
    t.float "end_longitude"
    t.string "location_source"
    t.float "latitude"
    t.float "longitude"
    t.integer "n_layovers", null: false
    t.integer "n_located_layovers"
    t.integer "n_standstill_records", null: false
    t.float "end_stop_meters"
    t.index ["route_day_id", "go_back"], name: "index_route_day_ends_on_route_day_id_and_go_back", unique: true
  end

  create_table "route_day_shapes", force: :cascade do |t|
    t.bigint "route_day_id", null: false
    t.integer "go_back", null: false
    t.timestamptz "shape_updated_at", null: false
    t.jsonb "points", null: false
    t.index ["route_day_id", "go_back"], name: "index_route_day_shapes_on_route_day_id_and_go_back", unique: true
  end

  create_table "route_day_stops", force: :cascade do |t|
    t.bigint "route_day_id", null: false
    t.integer "go_back", null: false
    t.integer "seq", null: false
    t.string "stop_name", null: false
    t.float "latitude"
    t.float "longitude"
    t.string "nearest_exit_name"
    t.float "nearest_exit_meters"
    t.integer "route_id", null: false
    t.integer "stop_location_id"
    t.index ["route_day_id", "route_id", "go_back", "seq"], name: "index_route_day_stops_on_route_day_route_direction_seq", unique: true
  end

  create_table "route_days", force: :cascade do |t|
    t.integer "route_id", null: false
    t.date "day", null: false
    t.string "route_name", null: false
    t.string "departure", null: false
    t.string "destination", null: false
    t.date "static_day", null: false
    t.timestamptz "loaded_at", null: false
    t.date "mrt_exits_day"
    t.string "day_type", null: false
    t.string "day_note"
    t.date "office_calendar_day", null: false
    t.date "public_toilets_day"
    t.jsonb "member_names", default: {}, null: false
    t.index ["route_id", "day"], name: "index_route_days_on_route_id_and_day", unique: true
  end

  create_table "trip_stop_counts", force: :cascade do |t|
    t.bigint "trip_id", null: false
    t.integer "seq", null: false
    t.integer "on_board", null: false
    t.index ["trip_id", "seq"], name: "index_trip_stop_counts_on_trip_id_and_seq", unique: true
  end

  create_table "trips", force: :cascade do |t|
    t.bigint "route_day_id", null: false
    t.string "bus_id", null: false
    t.integer "path_attribute_id", null: false
    t.integer "go_back", null: false
    t.string "band", null: false
    t.timestamptz "start_time", null: false
    t.timestamptz "end_time", null: false
    t.integer "first_seq", null: false
    t.integer "last_seq", null: false
    t.integer "n_events", null: false
    t.integer "n_stops_observed", null: false
    t.string "completeness", null: false
    t.boolean "start_from_arrival", null: false
    t.boolean "end_from_departure", null: false
    t.integer "route_id", null: false
    t.index ["route_day_id", "bus_id", "start_time"], name: "index_trips_on_route_day_id_and_bus_id_and_start_time", unique: true
  end

  add_foreign_key "layovers", "route_days", on_delete: :cascade
  add_foreign_key "route_day_depots", "route_days", on_delete: :cascade
  add_foreign_key "route_day_end_cells", "route_day_ends", on_delete: :cascade
  add_foreign_key "route_day_end_toilets", "route_day_ends", on_delete: :cascade
  add_foreign_key "route_day_ends", "route_days", on_delete: :cascade
  add_foreign_key "route_day_shapes", "route_days", on_delete: :cascade
  add_foreign_key "route_day_stops", "route_days", on_delete: :cascade
  add_foreign_key "trip_stop_counts", "trips", on_delete: :cascade
  add_foreign_key "trips", "route_days", on_delete: :cascade
end
