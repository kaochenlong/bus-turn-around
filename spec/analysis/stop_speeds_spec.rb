require "spec_helper"
require "json"
require "tmpdir"
require_relative "../support/duckdb"

# analysis/stop_speeds.sql runs on the fixture day after every stage through
# 20_trips, mrt_overlap.sql, whose haversine_meters gives the metres of a
# degree, gps_reports.sql and route_shape.sql with the route shapes file
# `shapes`: the fixture's, or one an example writes.
RSpec.describe "analysis/stop_speeds.sql" do
  # The fixture's inbound shape; the outbound one bent 60 metres east at 丙站;
  # and a shape that runs north along 121.5, 20 metres east and back south.
  def inbound_line = "LINESTRING (121.5003 25.06, 121.5003 25.0575, 121.5003 25.055, 121.5003 25.0525, 121.5003 25.05)"

  def bent_outbound_line = "LINESTRING (121.5 25.05, 121.5 25.0525, 121.500596 25.055, 121.5 25.0575, 121.5 25.06)"

  def there_and_back_line = "LINESTRING (121.5 25.05, 121.5 25.06, 121.500199 25.06, 121.500199 25.05)"

  def fixture_path(path) = File.join(DuckdbHelpers::FIXTURE_DATA, path)

  def sql_file(name) = File.read(File.join(DuckdbHelpers::ANALYSIS_DIR, name))

  # Runs the analysis above, then `setup`, SQL that replaces inputs, then
  # stop_speeds.sql and `query`. Keywords override variables.
  def stop_speeds(query, shapes: fixture_path("static/2026-10-19/GetBusShape.gz"), setup: "", **variables)
    files = [ sql_file("mrt_overlap.sql"), sql_file("gps_reports.sql"), sql_file("route_shape.sql"), setup, sql_file("stop_speeds.sql"), query ]
    run_sql_stages(through: "20_trips", mrt_exits_path: fixture_path("external/taipei-mrt-exits/2026-10-19.csv"),
                   bus_shape_path: shapes, query: files.join("\n"), **variables)
  end

  # stop_speeds on a route shapes file holding `rows`, the way the file has them.
  def with_shapes(rows, query, **options)
    Dir.mktmpdir do |dir|
      stop_speeds(query, shapes: File.join(dir, "shapes.json").tap { File.write(it, JSON.generate(rows)) }, **options)
    end
  end

  # A row of route 9001 with the keys of the real file.
  def shape_row(go_back, wkt)
    { "UniRouteId" => "0000900100", "RouteID" => 9001, "SubRouteID" => -1, "wkt" => wkt, "utime" => "2023-12-29 09:48:24", "GoBack" => go_back }
  end

  # SQL that replaces the stops of stage 10 with route 9001 outbound stops,
  # each [seq, latitude, longitude].
  def replace_stops_sql(stops)
    rows = stops.map { |seq, lat, lon| "(9001, 0, #{seq}, #{91000 + seq}, 'stop #{seq}', #{lat}, #{lon}, #{81000 + seq})" }
    "CREATE OR REPLACE TABLE stops AS SELECT * FROM (VALUES #{rows.join(', ')}) " \
      "AS t(route_id, go_back, seq, stop_id, stop_name, latitude, longitude, stop_location_id);"
  end

  # SQL that replaces the GPS reports with the given records, each [bus_id,
  # "HH:MM:SS" on the day or a full timestamp, latitude, longitude].
  def replace_gps_reports_sql(records)
    rows = records.map { |bus, at, lat, lon| "('#{bus}', #{lat}, #{lon}, 20, TIMESTAMP '#{at.include?(' ') ? at : "2026-10-19 #{at}"}')" }
    <<~SQL
      CREATE OR REPLACE TABLE gps_reports (bus_id VARCHAR, latitude DOUBLE, longitude DOUBLE, speed DOUBLE, data_time TIMESTAMP);
      #{"INSERT INTO gps_reports VALUES #{rows.join(', ')};" unless rows.empty?}
    SQL
  end

  # The reports of the spec's example for TEST-0001's outbound trip starting
  # 06:00:00, along the fixture's outbound shape.
  def example_reports
    [ [ "06:10:00", 25.052698, 121.5 ], [ "06:10:20", 25.053597, 121.5 ], [ "06:10:40", 25.054497, 121.5 ], [ "06:11:00", 25.055396, 121.5 ],
      [ "06:11:20", 25.056295, 121.5 ], [ "06:12:10", 25.056655, 121.5 ], [ "06:12:30", 25.056565, 121.5 ], [ "06:12:40", 25.059353, 121.5 ],
      [ "06:12:50", 25.059893, 121.500596 ], [ "06:13:00", 25.059803, 121.5 ] ].map { [ "TEST-0001", *it ] }
  end

  def speeds_query = "SELECT bus_id, strftime(start_time, '%H:%M:%S') AS start, seq, band, meters, seconds FROM trip_stop_speeds ORDER BY bus_id, start_time, seq"

  def speed_rows(rows) = pairs(rows, "bus_id", "start", "seq", "band", "meters", "seconds")

  def positions_query(go_back) = "SELECT seq, round(shape_meters, 1) AS meters FROM stop_positions WHERE route_id = 9001 AND go_back = #{go_back} ORDER BY seq"

  def legs_query(go_back) = "SELECT seq, next_seq FROM stop_legs WHERE go_back = #{go_back} ORDER BY seq"

  def pairs(rows, *keys) = rows.map { it.values_at(*keys) }

  def member_day = { day: Date.new(2026, 10, 23), static_day: Date.new(2026, 10, 23), member_route_ids: [ 9001, 9050 ], shapes: fixture_path("static/2026-10-23/GetBusShape.gz") }

  describe "站牌在路線軌跡上的位置" do
    it "fixture 日去程五站在 0.0、278.0、556.0、834.0、1111.9 公尺" do
      expect(pairs(stop_speeds(positions_query(0)), "seq", "meters")).to eq([ [ 0, 0.0 ], [ 1, 278.0 ], [ 2, 556.0 ], [ 3, 834.0 ], [ 4, 1111.9 ] ])
    end

    it "返程五站也在同樣的五個位置" do
      expect(pairs(stop_speeds(positions_query(1)), "seq", "meters")).to eq([ [ 5, 0.0 ], [ 6, 278.0 ], [ 7, 556.0 ], [ 8, 834.0 ], [ 9, 1111.9 ] ])
    end

    it "去程的 leg 是 0 到 3、返程是 5 到 8，各接到下一站" do
      rows = stop_speeds("SELECT seq, next_seq FROM stop_legs ORDER BY go_back, seq")
      expect(pairs(rows, "seq", "next_seq")).to eq([ [ 0, 1 ], [ 1, 2 ], [ 2, 3 ], [ 3, 4 ], [ 5, 6 ], [ 6, 7 ], [ 7, 8 ], [ 8, 9 ] ])
    end

    it "去程的線在丙站往東彎 60 公尺時，91002 離線 58.7 公尺沒有位置，後兩站沿著彎過去的線在 846.8 與 1124.8 公尺" do
      rows = with_shapes([ shape_row(0, bent_outbound_line), shape_row(1, inbound_line) ], positions_query(0))
      expect(pairs(rows, "seq", "meters")).to eq([ [ 0, 0.0 ], [ 1, 278.0 ], [ 2, nil ], [ 3, 846.8 ], [ 4, 1124.8 ] ])
    end

    it "沒有位置的站被跨過：去程的 leg 是 0、1、3，leg 1 從 91001 接到 91003" do
      rows = with_shapes([ shape_row(0, bent_outbound_line), shape_row(1, inbound_line) ], legs_query(0))
      expect(pairs(rows, "seq", "next_seq")).to eq([ [ 0, 1 ], [ 1, 3 ], [ 3, 4 ] ])
    end

    it "線來回經過同一站、離回程那一段近不到 15 公尺時，站落在先經過的那一段，下一站排在它後面" do
      rows = with_shapes([ shape_row(0, there_and_back_line) ], positions_query(0),
                         setup: replace_stops_sql([ [ 0, 25.05, 121.5 ], [ 1, 25.0525, 121.500119 ], [ 2, 25.0575, 121.5 ] ]))
      expect(pairs(rows, "seq", "meters")).to eq([ [ 0, 0.0 ], [ 1, 278.0 ], [ 2, 834.0 ] ])
    end

    it "路線軌跡檔是空的時，每一站都沒有位置" do
      expect(with_shapes([], "SELECT count(*) AS n, count(shape_meters) AS placed FROM stop_positions").first).to eq("n" => 10, "placed" => 0)
    end

    it "成員日 2026-10-23：9050 的站牌都沒有位置，9001 的照常有" do
      rows = stop_speeds("SELECT route_id, count(shape_meters) AS placed, count(*) AS n FROM stop_positions GROUP BY route_id ORDER BY route_id", **member_day)
      expect(rows).to eq([ { "route_id" => 9001, "placed" => 10, "n" => 10 }, { "route_id" => 9050, "placed" => 0, "n" => 10 } ])
    end
  end

  describe "一趟在兩站之間的車速" do
    it "fixture 日：只有 TEST-0001 06:00 那趟有一列，leg 1 其餘時段 200.0 公尺 40 秒；06:30 在 A 點那筆離線 53.8 公尺不算" do
      expect(speed_rows(stop_speeds(speeds_query))).to eq([ [ "TEST-0001", "06:00:00", 1, "other", 200.0, 40 ] ])
    end

    it "規格的十筆回報：leg 1 200.0 公尺 40 秒、leg 2 100.0 公尺 20 秒、leg 3 50.0 公尺 20 秒，都是其餘" do
      rows = stop_speeds(speeds_query, setup: replace_gps_reports_sql(example_reports))
      expect(speed_rows(rows)).to eq([ [ "TEST-0001", "06:00:00", 1, "other", 200.0, 40 ], [ "TEST-0001", "06:00:00", 2, "other", 100.0, 20 ],
                                       [ "TEST-0001", "06:00:00", 3, "other", 50.0, 20 ] ])
    end

    it "時段看車開進那兩站之間的時刻：06:35 發車的那趟在 07:05 開過 leg 1，是早尖峰" do
      reports = [ [ "TEST-0002", "07:05:00", 25.052698, 121.5 ], [ "TEST-0002", "07:05:20", 25.053597, 121.5 ] ]
      expect(speed_rows(stop_speeds(speeds_query, setup: replace_gps_reports_sql(reports)))).to eq([ [ "TEST-0002", "06:35:00", 1, "morning_peak", 100.0, 20 ] ])
    end

    it "起點只有到站時刻的趟次不算：TEST-0002 10:20 那趟沒有列" do
      reports = [ [ "TEST-0002", "10:30:00", 25.052698, 121.5 ], [ "TEST-0002", "10:30:20", 25.053597, 121.5 ] ]
      expect(stop_speeds(speeds_query, setup: replace_gps_reports_sql(reports))).to eq([])
    end

    it "成員路線的趟次不算：成員日 TEST-0005 的 9050 那趟沒有列，同一天 9001 返程那趟有 leg 6 的早尖峰 100.0 公尺 20 秒" do
      reports = [ [ "2026-10-23 07:10:00", 25.052698, 121.5 ], [ "2026-10-23 07:10:20", 25.053597, 121.5 ],
                  [ "2026-10-23 08:10:00", 25.057302, 121.5003 ], [ "2026-10-23 08:10:20", 25.056403, 121.5003 ] ].map { [ "TEST-0005", *it ] }
      rows = stop_speeds(speeds_query, setup: replace_gps_reports_sql(reports), **member_day)
      expect(speed_rows(rows)).to eq([ [ "TEST-0005", "08:00:00", 6, "morning_peak", 100.0, 20 ] ])
    end

    it "落在斜線段的外框裡、但離線超過 50 公尺的回報也不算：線在丙站往東彎時，東邊 100 公尺的兩筆沒有列" do
      reports = [ [ "TEST-0001", "06:20:00", 25.052698, 121.500993 ], [ "TEST-0001", "06:20:20", 25.053058, 121.500993 ] ]
      rows = with_shapes([ shape_row(0, bent_outbound_line), shape_row(1, inbound_line) ], speeds_query, setup: replace_gps_reports_sql(reports))
      expect(rows).to eq([])
    end

    it "路線軌跡檔是空的時，同樣的十筆回報沒有任何一列" do
      expect(with_shapes([], speeds_query, setup: replace_gps_reports_sql(example_reports))).to eq([])
    end
  end
end
