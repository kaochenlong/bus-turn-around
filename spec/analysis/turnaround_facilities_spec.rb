require "spec_helper"
require "fileutils"
require_relative "../support/duckdb"

RSpec.describe "analysis/turnaround_facilities.sql" do
  # A point of the README section on vehicle GPS.
  def point(name) = { "A" => [ 25.060400, 121.500300 ], "B" => [ 25.060580, 121.500300 ],
                      "C" => [ 25.065800, 121.500300 ], "D" => [ 25.060490, 121.500300 ] }.fetch(name)

  def fixture_path(path) = File.join(DuckdbHelpers::FIXTURE_DATA, path)

  def sql_file(name) = File.read(File.join(DuckdbHelpers::ANALYSIS_DIR, name))

  # Runs every stage, mrt_overlap.sql (which defines haversine_meters) and
  # turnaround_facilities.sql on the fixture day with both ends stopping, then
  # `setup`, SQL that replaces inputs, and `query`. Keywords override variables.
  def facilities(query, setup: "", **variables)
    defaults = { mrt_exits_path: fixture_path("external/taipei-mrt-exits/2026-10-19.csv"),
                 public_toilets_path: fixture_path("external/public-toilets/2026-10-19.csv"), end_nature_0: "stop", end_nature_1: "stop" }
    run_sql_stages(through: "50_quality", **defaults.merge(variables),
                   query: [ sql_file("mrt_overlap.sql"), sql_file("turnaround_facilities.sql"), setup, query ].join("\n"))
  end

  def ends(**options) = facilities("SELECT * FROM turnaround_ends ORDER BY go_back", **options)

  def end_toilets(go_back, **options)
    facilities("SELECT name, category, address, meters FROM end_toilets WHERE go_back = #{go_back} ORDER BY meters, name", **options)
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

  # SQL that replaces the snapshot's toilets with the given ones, each
  # [name, address, latitude], all at longitude 121.5 and in the category 公園.
  def replace_public_toilets_sql(toilets)
    rows = toilets.map { |name, address, latitude| "('#{name}', '公園', '#{address}', #{latitude}, 121.5)" }
    "CREATE OR REPLACE TABLE public_toilets AS SELECT * FROM (VALUES #{rows.join(', ')}) AS t(name, category, address, latitude, longitude);"
  end

  # `count` reports of one vehicle at one point, ten seconds apart from `from` ("HH:MM:SS").
  def reports(bus, from, (latitude, longitude), count, speed: 0)
    start = Time.utc(2026, 10, 19, *from.split(":").map(&:to_i))
    (0...count).map { [ bus, (start + (10 * it)).strftime("%H:%M:%S"), latitude, longitude, speed ] }
  end

  # Trips of one vehicle that start on the hour from 06:00, alternate between
  # direction 0 and 1 and last 50 minutes, so its layovers end in direction 0
  # at 06:50, 08:50 and 10:50, and in direction 1 at 07:50 and 09:50.
  def alternating_trips(bus, count)
    (0...count).map { |i| { bus_id: bus, go_back: i % 2, start: format("%02d:00", 6 + i), finish: format("%02d:50", 6 + i) } }
  end

  # Trips and GPS reports in place of the fixture's, with no records on other routes.
  def injected(trips, gps) = [ replace_trips_sql(trips), replace_other_route_events_sql([]), replace_gps_reports_sql(gps) ].join("\n")

  describe "fixture 的 2026-10-19，兩端都是停車端" do
    let(:rows) { ends }

    it "戊站端（方向 0）的位置是 README 手算的 25.060422, 121.500300，來源 standstill" do
      expect(rows.first.values_at("location_source", "latitude", "longitude")).to eq([ "standstill", 25.060422, 121.5003 ])
    end

    it "戊站端有 10 筆折返停留、3 筆在位置 150 公尺內、29 筆靜止回報" do
      expect(rows.first.values_at("n_layovers", "n_located_layovers", "n_standstill_records")).to eq([ 10, 3, 29 ])
    end

    it "戊站端的末站是第 4 站戊站，位置離它 55.8 公尺（容許 0.1 公尺）" do
      expect(rows.first.values_at("end_seq", "end_stop_name", "end_latitude", "end_longitude", "end_stop_meters")).to match(
        [ 4, "戊站", 25.06, 121.5, a_value_within(0.1).of(55.8) ]
      )
    end

    it "甲站端（方向 1）的位置是 E：8 筆折返停留、1 筆在 150 公尺內、8 筆靜止回報，離末站甲站 45.0 公尺" do
      expect(rows.last.values_at("location_source", "latitude", "longitude", "n_layovers", "n_located_layovers", "n_standstill_records", "end_stop_meters"))
        .to match([ "standstill", 25.0497, 121.5006, 8, 1, 8, a_value_within(0.1).of(45.0) ])
    end

    it "戊站端 500 公尺內存三間，一間一列：同地址的戊站公園兩間，再來是地址帶逗號的戊站加油站" do
      expect(end_toilets(0).map { it.values_at("name", "category", "address", "meters") }).to eq(
        [ [ "戊站公園-男廁", "公園", "臺北市測試區戊路2號", 251.7 ], [ "戊站公園-女廁", "公園", "臺北市測試區戊路2號", 253.3 ],
          [ "戊站加油站-混合廁所", "商業營業場所", "臺北市測試區戊路1號, 2樓", 451.9 ] ]
      )
    end

    it "甲站端 500 公尺內存兩間：甲站機關 120.1 公尺、甲站對面 134.4 公尺，遠方公廁兩端都不存" do
      expect(end_toilets(1).map { it.values_at("name", "category", "meters") }).to eq(
        [ [ "甲站機關-無障礙廁所", "民眾洽公場所", 120.1 ], [ "甲站對面-男廁", "交通", 134.4 ] ]
      )
    end

    it "靜止格只有戊站端 (25.0604, 121.5002) 那一格：25 筆、3 台車、3 筆折返停留；C 與 E 的格只有一台車" do
      expect(facilities("SELECT * FROM standstill_cells")).to eq(
        [ { "go_back" => 0, "cell_latitude" => 25.0604, "cell_longitude" => 121.5002, "n_records" => 25, "n_buses" => 3, "n_layovers" => 3 } ]
      )
    end
  end

  describe "方向 0 是開過去就走那一端時" do
    it "位置是末站戊站，來源 end_stop、0.0 公尺、沒有 150 公尺內的筆數，靜止回報仍記方向 0 的 29 筆" do
      expect(ends(end_nature_0: "pass_through").first.values_at("latitude", "longitude", "location_source", "end_stop_meters", "n_located_layovers", "n_standstill_records"))
        .to eq([ 25.06, 121.5, "end_stop", 0.0, nil, 29 ])
    end

    it "方向 0 仍存 (25.0604, 121.5002) 那一格" do
      expect(facilities("SELECT go_back, cell_latitude, cell_longitude FROM standstill_cells", end_nature_0: "pass_through")).to eq(
        [ { "go_back" => 0, "cell_latitude" => 25.0604, "cell_longitude" => 121.5002 } ]
      )
    end
  end

  it "末站只看頁面路線的站序：成員路線 9050 去程多一站 seq 5 時，方向 0 的末站仍是 9001 的第 4 站戊站" do
    setup = "INSERT INTO stops (route_id, go_back, seq, stop_id, stop_name, latitude, longitude, stop_location_id) VALUES (9050, 0, 5, 95099, '多出來的站', 25.07, 121.5, 85099);"
    rows = facilities("SELECT end_seq, end_stop_name FROM turnaround_ends WHERE go_back = 0", setup:, member_route_ids: [ 9001, 9050 ])
    expect(rows).to eq([ { "end_seq" => 4, "end_stop_name" => "戊站" } ])
  end

  it "任一端是 unknown（路線還沒有設定）時，三張結果表都是空的" do
    query = "SELECT (SELECT count(*) FROM turnaround_ends) AS ends, (SELECT count(*) FROM end_toilets) AS toilets, (SELECT count(*) FROM standstill_cells) AS cells"
    expect(facilities(query, end_nature_0: "unknown").first).to eq("ends" => 0, "toilets" => 0, "cells" => 0)
  end

  describe "兩端的性質" do
    it "不是 stop、pass_through 或 unknown 時，整段 SQL 失敗，訊息指出 end_nature" do
      expect { ends(end_nature_1: "stopping") }.to raise_error(RuntimeError, /end_nature/)
    end

    it "沒有設定 end_nature_1 時也失敗" do
      query = [ sql_file("mrt_overlap.sql"), sql_file("turnaround_facilities.sql"), "SELECT 1" ].join("\n")
      run = -> { run_sql_stages(through: "50_quality", mrt_exits_path: fixture_path("external/taipei-mrt-exits/2026-10-19.csv"), end_nature_0: "stop", query:) }
      expect(&run).to raise_error(RuntimeError, /end_nature/)
    end
  end

  describe "灌入的資料" do
    it "最密集的靜止點當種子：A 12 筆、B 3 筆得 25.060436；600 公尺外的 C 與速度 15 的 D 拉不動它，靜止回報 19 筆" do
      gps = reports("TEST-0001", "06:50:00", point("A"), 12) + reports("TEST-0001", "06:52:00", point("B"), 3) +
            reports("TEST-0001", "06:53:00", point("C"), 4) + reports("TEST-0001", "06:54:00", point("D"), 6, speed: 15)
      row = ends(setup: injected(alternating_trips("TEST-0001", 2), gps)).first
      expect(row.values_at("latitude", "longitude", "n_standstill_records")).to eq([ 25.060436, 121.5003, 19 ])
    end

    it "三筆折返停留結束在停車端，兩筆有靜止回報、一筆時間窗裡沒有任何記錄：3 筆、2 筆在 150 公尺內、靜止回報 7 筆" do
      gps = reports("TEST-0001", "06:51:00", point("A"), 4) + reports("TEST-0001", "08:51:00", point("B"), 3)
      row = ends(setup: injected(alternating_trips("TEST-0001", 6), gps)).first
      expect(row.values_at("n_layovers", "n_located_layovers", "n_standstill_records")).to eq([ 3, 2, 7 ])
    end

    describe "停車端當天沒有任何速度 0 的回報時" do
      let(:setup) { injected(alternating_trips("TEST-0001", 6), reports("TEST-0001", "06:51:00", point("A"), 5, speed: 15)) }

      it "那一端沒有位置、來源與公尺，只記 3 筆折返停留與 0 筆靜止回報" do
        expect(ends(setup:).first.values_at("location_source", "latitude", "longitude", "n_layovers", "n_located_layovers", "end_stop_meters", "n_standstill_records"))
          .to eq([ nil, nil, nil, 3, nil, nil, 0 ])
      end

      it "那一端不存任何公廁" do
        expect(end_toilets(0, setup:)).to eq([])
      end
    end

    describe "兩個靜止點的 50 公尺鄰域和都是 8、相距 111 公尺時" do
      let(:setup) do
        gps = reports("TEST-0001", "06:51:00", [ 25.0510, 121.5003 ], 8) + reports("TEST-0001", "06:53:00", [ 25.0500, 121.5003 ], 8)
        injected(alternating_trips("TEST-0001", 2), gps)
      end

      it "種子取緯度小的 25.0500" do
        expect(ends(setup:).first.values_at("latitude", "longitude")).to eq([ 25.05, 121.5003 ])
      end

      it "同一份輸入跑兩次，結果相同" do
        first_run = ends(setup:)
        expect(ends(setup:)).to eq(first_run)
      end
    end

    it "座標轉不成數字的回報不是靜止回報" do
      gps = reports("TEST-0001", "06:51:00", point("A"), 3) + [ [ "TEST-0001", "06:55:00", "NULL", 121.5003, 0 ] ]
      expect(ends(setup: injected(alternating_trips("TEST-0001", 2), gps)).first["n_standstill_records"]).to eq(3)
    end

    it "只有兩台車停過的格子不存，那一端的靜止回報仍算進它們：0 格、20 筆" do
      setup = injected(alternating_trips("TEST-0001", 2) + alternating_trips("TEST-0002", 2),
                       reports("TEST-0001", "06:51:00", point("A"), 10) + reports("TEST-0002", "06:51:00", point("A"), 10))
      query = "SELECT (SELECT count(*) FROM standstill_cells) AS cells, (SELECT n_standstill_records FROM turnaround_ends WHERE go_back = 0) AS reports"
      expect(facilities(query, setup:).first).to eq("cells" => 0, "reports" => 20)
    end
  end

  describe "公廁照間存在 500 公尺內" do
    # The location of direction 0 as a pass-through end is its last stop 戊站 at 25.06, 121.5.
    def stored(toilets) = end_toilets(0, end_nature_0: "pass_through", setup: replace_public_toilets_sql(toilets))

    it "同地址的 250.0 與 251.0 公尺兩間、另一地址的 450.0 公尺各存一列，1,200 公尺那間不存" do
      toilets = [ %w[甲公園-男廁 測試路1號 25.062248304], %w[甲公園-女廁 測試路1號 25.062257297],
                  %w[乙加油站-男廁 測試路2號 25.064046947], %w[丙公廁 測試路3號 25.070791859] ]
      expect(stored(toilets).map { it.values_at("name", "address", "meters") }).to eq(
        [ [ "甲公園-男廁", "測試路1號", 250.0 ], [ "甲公園-女廁", "測試路1號", 251.0 ], [ "乙加油站-男廁", "測試路2號", 450.0 ] ]
      )
    end

    it "不同地址、都是 120.0 公尺的甲公廁與乙公廁都存" do
      toilets = [ %w[甲公廁 測試路4號 25.061079186], %w[乙公廁 測試路5號 25.058920814] ]
      expect(stored(toilets).map { it.values_at("name", "meters") }).to contain_exactly([ "甲公廁", 120.0 ], [ "乙公廁", 120.0 ])
    end
  end

  describe "靜止格的西南角" do
    [
      [ 25.060400, 121.500300, 25.0604, 121.5002 ], [ 25.060580, 121.500300, 25.0604, 121.5002 ],
      [ 25.065800, 121.500300, 25.0658, 121.5002 ], [ 25.049700, 121.500600, 25.0496, 121.5006 ]
    ].each do |latitude, longitude, cell_latitude, cell_longitude|
      it "#{latitude}, #{longitude} 的回報落在 #{cell_latitude}, #{cell_longitude} 那一格" do
        row = facilities("SELECT standstill_cell_corner(#{latitude}::DOUBLE) AS lat, standstill_cell_corner(#{longitude}::DOUBLE) AS lon").first
        expect(row.values).to eq([ cell_latitude, cell_longitude ])
      end
    end
  end

  describe "從 bus_data 讀進來的回報" do
    # A data root whose bus_data holds only the given records, in the 06 hour
    # file of 2026-10-19; the other feeds link to the fixture.
    def with_bus_data(records)
      Dir.mktmpdir("bus-data") do |root|
        %w[bus_event bus_seat_event static].each { File.symlink(fixture_path(it), File.join(root, it)) }
        FileUtils.mkdir_p(File.join(root, "bus_data/2026-10-19"))
        File.write(File.join(root, "bus_data/2026-10-19/06.jsonl"), records.map { "#{JSON.generate(it)}\n" }.join)
        yield root
      end
    end

    # A record of TEST-0001 at A, fetched in the second of its DataTime.
    def record(at, speed)
      { "BusID" => "TEST-0001", "Longitude" => "121.500300", "Latitude" => "25.060400", "Speed" => speed,
        "DataTime" => "2026-10-19 #{at}", "_fetched_at" => "2026-10-18T22:#{at[3, 5]}Z" }
    end

    it "速度寫成 \"0.0\" 也是 0，\"15\" 不是：TEST-0001 06:50 到 07:00 的時間窗裡 1 筆靜止回報" do
      count = with_bus_data([ record("06:55:00", "0.0"), record("06:56:00", "15") ]) { |root| ends(data_root: root).first["n_standstill_records"] }
      expect(count).to eq(1)
    end
  end
end
