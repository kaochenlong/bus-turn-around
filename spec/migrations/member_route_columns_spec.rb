require "rails_helper"

# The three migrations that give the derived tables route_id,
# stop_location_id and member_names, run against rows loaded before them.
RSpec.describe "成員路線欄位的 migration", type: :model do
  let(:context) { ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate").to_s) }
  let(:first_version) { context.migrations.find { it.name == "AddMemberRouteColumnsToDerivedTables" }.version }
  let(:connection) { ActiveRecord::Base.connection }

  def migrate_to(version) = ActiveRecord::Migration.suppress_messages { context.migrate(version) }

  # A route day with one stop and one trip the way the loader wrote them
  # before the migrations: no route_id on the rows, no member_names.
  def insert_old_rows
    route_day_id = connection.select_value(<<~SQL)
      INSERT INTO route_days (route_id, day, route_name, departure, destination, static_day, loaded_at, day_type, office_calendar_day)
      VALUES (9001, '2026-10-19', '測試幹線', '甲站', '戊站', '2026-10-19', now(), 'weekday', '2026-10-19') RETURNING id
    SQL
    connection.execute("INSERT INTO route_day_stops (route_day_id, go_back, seq, stop_name) VALUES (#{route_day_id}, 0, 0, '甲站')")
    connection.execute(<<~SQL)
      INSERT INTO trips (route_day_id, bus_id, path_attribute_id, go_back, band, start_time, end_time, first_seq, last_seq, n_events,
                         n_stops_observed, completeness, start_from_arrival, end_from_departure)
      VALUES (#{route_day_id}, 'TEST-0001', 9001, 0, 'other', '2026-10-19 06:00+08', '2026-10-19 06:50+08', 0, 4, 10, 5, 'complete', false, false)
    SQL
  end

  # Migrates down to just before the three migrations, writes the old-style
  # rows, and migrates up again; the example's transaction undoes it all.
  def migrate_with_old_rows
    migrate_to(context.migrations.map(&:version).select { it < first_version }.max)
    insert_old_rows
    migrate_to(nil)
  end

  def stored_row
    connection.select_one(<<~SQL)
      SELECT s.route_id AS stop_route_id, s.stop_location_id, t.route_id AS trip_route_id, d.member_names::text AS member_names
      FROM route_days d JOIN route_day_stops s ON s.route_day_id = d.id JOIN trips t ON t.route_day_id = d.id
    SQL
  end

  it "先有的站序與趟次回填成路線日的路線 Id，站位是空的，路線日的 member_names 是 {}" do
    migrate_with_old_rows
    expect(stored_row).to eq("stop_route_id" => 9001, "stop_location_id" => nil, "trip_route_id" => 9001, "member_names" => "{}")
  end
end
