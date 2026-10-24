require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/end_nature_evidence.sql" do
  # A point of the README section on vehicle GPS.
  def point(name) = { "A" => [ 25.060400, 121.500300 ], "D" => [ 25.060490, 121.500300 ] }.fetch(name)

  def fixture_path(path) = File.join(DuckdbHelpers::FIXTURE_DATA, path)

  def sql_file(name) = File.read(File.join(DuckdbHelpers::ANALYSIS_DIR, name))

  # Runs every stage, mrt_overlap.sql (which defines haversine_meters),
  # turnaround_facilities.sql with both ends unknown (which builds
  # gps_reports), as the survey runs them, and end_nature_evidence.sql on the
  # fixture day with 9050 counted with 9001, then `setup`, SQL that replaces
  # inputs, and `query`. Keywords override variables.
  def evidence(query, setup: "", **variables)
    defaults = { member_route_ids: [ 9001, 9050 ], mrt_exits_path: fixture_path("external/taipei-mrt-exits/2026-10-19.csv"),
                 public_toilets_path: fixture_path("external/public-toilets/2026-10-19.csv"), end_nature_0: "unknown", end_nature_1: "unknown" }
    files = %w[mrt_overlap.sql turnaround_facilities.sql end_nature_evidence.sql].map { sql_file(it) }
    run_sql_stages(through: "50_quality", **defaults.merge(variables), query: [ *files, setup, query ].join("\n"))
  end

  # The layovers ending in direction `go_back`, in time order, each as
  # [vehicle, end, next start, minutes, next route Id, next direction, stop
  # gap, reports, longest standstill, farthest], times as HH:MM:SS.
  def layovers(go_back, where: "TRUE", **options)
    query = <<~SQL
      SELECT bus_id, strftime(end_time, '%H:%M:%S') AS end_at, strftime(next_start_time, '%H:%M:%S') AS next_at, minutes,
             next_route_id, next_go_back, stop_gap_meters, n_reports, longest_still_minutes, farthest_meters
      FROM layover_evidence WHERE go_back = #{go_back} AND #{where} ORDER BY end_time, bus_id
    SQL
    evidence(query, **options).map(&:values)
  end

  # SQL that replaces the GPS reports read from bus_data with the given
  # records, each [bus_id, "HH:MM:SS" on 2026-10-19, latitude, longitude, speed].
  def replace_gps_reports_sql(records)
    rows = records.map { |bus, at, lat, lon, speed| "('#{bus}', #{lat}, #{lon}, #{speed}, TIMESTAMP '2026-10-19 #{at}')" }
    <<~SQL
      CREATE OR REPLACE TABLE gps_reports (bus_id VARCHAR, latitude DOUBLE, longitude DOUBLE, speed DOUBLE, data_time TIMESTAMP);
      #{"INSERT INTO gps_reports VALUES #{rows.join(', ')};" unless rows.empty?}
    SQL
  end

  # `count` reports of TEST-0001 at one point, a minute apart from `from` ("HH:MM").
  def reports(from, (latitude, longitude), count, speed: 0)
    start = Time.utc(2026, 10, 19, *from.split(":").map(&:to_i))
    (0...count).map { [ "TEST-0001", (start + (60 * it)).strftime("%H:%M:%S"), latitude, longitude, speed ] }
  end

  # TEST-0001 running 06:00 to 06:50 in direction 0 and 07:00 to 07:50 in
  # direction 1, so its one layover ends in direction 0 at 06:50, with the
  # given GPS reports and no records on other routes.
  def one_layover(gps, first_route_id: 9001)
    trips = [ { bus_id: "TEST-0001", route_id: first_route_id, go_back: 0, start: "06:00", finish: "06:50" },
              { bus_id: "TEST-0001", go_back: 1, start: "07:00", finish: "07:50" } ]
    [ replace_trips_sql(trips), replace_other_route_events_sql([]), replace_gps_reports_sql(gps) ].join("\n")
  end

  describe "fixture 的 2026-10-19，路線 9001（成員 9050）" do
    # The spec's Example table of the layovers with GPS reports at 戊站.
    let(:example_rows) do
      [ [ "TEST-0001", "06:50:00", "07:00:00", 10.0, 9001, 1, 30.2, 21, 2.0, 64.5 ],
        [ "TEST-0003", "07:53:00", "08:08:00", 15.0, 9001, 0, 1111.9, 5, 8.0, 53.8 ],
        [ "TEST-0004", "08:03:00", "08:15:00", 12.0, 9001, 1, 30.2, 5, 8.0, 44.5 ],
        [ "TEST-0001", "11:30:00", "12:26:00", 56.0, 9001, 1, 30.2, 4, 35.0, 644.9 ] ]
    end

    it "方向 0（結束在戊站）有回報的 4 筆，數字照規格的 Example 表" do
      expect(layovers(0, where: "n_reports > 0")).to eq(example_rows)
    end

    it "方向 0 共 10 筆折返停留，另外 6 筆沒有回報：回報 0 筆，最長靜止與最遠離站都是空的" do
      query = "SELECT count(*) AS n, count(*) FILTER (WHERE n_reports = 0 AND longest_still_minutes IS NULL AND farthest_meters IS NULL) AS n_without FROM layover_evidence WHERE go_back = 0"
      expect(evidence(query).first).to eq("n" => 10, "n_without" => 6)
    end

    it "方向 1（結束在甲站）有 8 筆折返停留，只有 TEST-0001 08:30 那筆有回報" do
      rows = layovers(1)
      expect([ rows.size, rows.reject { it[7].zero? } ]).to eq([ 8, [ [ "TEST-0001", "08:30:00", "08:42:00", 12.0, 9001, 0, 30.2, 8, 7.0, 45.0 ] ] ])
    end

    it "速度 15 的回報切斷靜止：TEST-0001 06:50 那筆是後面 06:58 到 07:00 那段的 2.0 分鐘，不是第一筆到最後一筆的 10 分鐘" do
      expect(layovers(0, where: "bus_id = 'TEST-0001' AND end_time = TIMESTAMP '2026-10-19 06:50:00'").map { it[8] }).to eq([ 2.0 ])
    end

    it "結束在每一端的配對照 category 數：方向 0 有 12 組、方向 1 有 11 組，末站是戊站與甲站" do
      expect(evidence("SELECT * FROM end_pair_counts ORDER BY go_back").map(&:values)).to eq(
        [ [ 0, "戊站", 12, 10, 1, 1, 0, 0 ], [ 1, "甲站", 11, 8, 2, 0, 1, 0 ] ]
      )
    end
  end

  describe "灌入的資料" do
    it "跳到 50 公尺外的回報切斷靜止：06:51、06:52 在一點，06:53、06:56 在 60.0 公尺外，最長靜止是 3.0 分鐘" do
      gps = reports("06:51", [ 25.0604, 121.5003 ], 2) + [ [ "TEST-0001", "06:53:00", 25.06094, 121.5003, 0 ], [ "TEST-0001", "06:56:00", 25.06094, 121.5003, 0 ] ]
      expect(layovers(0, setup: one_layover(gps)).map { it[8] }).to eq([ 3.0 ])
    end

    it "有回報但沒有一筆速度 0：最長靜止是 0.0，回報與最遠離站照算（D 離戊站對面 54.5 公尺）" do
      rows = layovers(0, setup: one_layover(reports("06:51", point("D"), 5, speed: 15)))
      expect(rows.map { it.values_at(7, 8, 9) }).to eq([ [ 5, 0.0, 54.5 ] ])
    end

    it "座標轉不成數字的回報不算：A 3 筆加 1 筆緯度是 NULL，回報 3 筆" do
      gps = reports("06:51", point("A"), 3) + [ [ "TEST-0001", "06:55:00", "NULL", 121.5003, 0 ] ]
      expect(layovers(0, setup: one_layover(gps)).map { it[7] }).to eq([ 3 ])
    end

    it "結束那一趟是成員路線時，末站取成員路線自己的站序：9050 去程多一站 seq 5，兩站距離 1112.4 公尺、最遠離站 44.5 公尺" do
      setup = "INSERT INTO stops (route_id, go_back, seq, stop_id, stop_name, latitude, longitude, stop_location_id) VALUES (9050, 0, 5, 95099, '多出來的站', 25.07, 121.5, 85099);\n" \
              "#{one_layover(reports('06:51', point('A'), 3), first_route_id: 9050)}"
      expect(layovers(0, setup:).map { it.values_at(4, 5, 6, 9) }).to eq([ [ 9001, 1, 1112.4, 44.5 ] ])
    end
  end
end
