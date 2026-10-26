require "rails_helper"
require_relative "../support/duckdb"

RSpec.describe RouteDayLoader, :duckdb, type: :model do
  let(:day) { Date.new(2026, 10, 19) }

  # What the loader prints goes to a StringIO the example does not read.
  def load_day = described_class.new(route_id: 9001, day:, data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb", out: StringIO.new).call

  def stored_counts
    [ Trip.count, Layover.count, TripStopCount.count, RouteDayStop.count, RouteDay.count, RouteDayEnd.count, RouteDayEndToilet.count, RouteDayEndCell.count,
      RouteDayShape.count, RouteDayDepot.count, TripStopSpeed.count ]
  end

  def fixture(path) = File.join(DuckdbHelpers::FIXTURE_DATA, path)

  # Links the fixture's raw feeds and the named external snapshot folders into
  # `dir`, a data root that a test then completes with its own snapshots.
  def link_fixture(dir, *externals)
    %w[bus_event bus_seat_event bus_data static].each { File.symlink(fixture(it), File.join(dir, it)) }
    FileUtils.mkdir_p(File.join(dir, "external"))
    externals.each { File.symlink(fixture("external/#{it}"), File.join(dir, "external", it)) }
    dir
  end

  # Makes the next export write a row of `file` whose trip does not exist, a
  # trip stop count unless another file and row are given, so the load fails
  # after the old day has been deleted inside the transaction.
  def break_next_export(file = "trip_stop_counts.csv", row = "TEST-9999,2026-10-19 06:00:00+08:00,0,1")
    allow(AnalysisRun).to receive(:run).and_wrap_original do |original, *args, **options|
      original.call(*args, **options).tap do
        File.open(File.join(args[1].fetch(:derived_dir), file), "a") { it.puts(row) }
      end
    end
  end

  it "fixture 2026-10-19 寫入兩次，趟次 27、折返停留 18、趟次站 96、站序 20（9001 與成員路線 9050 各 10）、路線日 1、兩端 2、公廁 5、靜止格 1、路線軌跡 2、調度站 1、站間車速 1，第二次後不變" do
    load_day
    expect { load_day }.not_to(change { stored_counts }.from([ 27, 18, 96, 20, 1, 2, 5, 1, 2, 1, 1 ]))
  end

  describe "寫入後的站間車速" do
    before { load_day }

    it "一列：TEST-0001 06:00 那趟的 leg 1，其餘時段，200.0 公尺 40 秒" do
      rows = TripStopSpeed.joins(:trip).pluck("trips.bus_id", "trips.start_time", :seq, :band, :meters, :seconds)
      expect(rows).to eq([ [ "TEST-0001", Time.zone.parse("2026-10-19 06:00"), 1, "other", 200.0, 40 ] ])
    end

    it "9001 去程五站在路線軌跡上的 0.0、278.0、556.0、834.0、1111.9 公尺，成員 9050 的站都沒有位置" do
      positions = RouteDayStop.where(route_id: 9001, go_back: 0).order(:seq).pluck(:shape_meters)
      expect([ positions, RouteDayStop.where(route_id: 9050).where.not(shape_meters: nil).count ]).to eq([ [ 0.0, 278.0, 556.0, 834.0, 1111.9 ], 0 ])
    end
  end

  describe "寫入後的成員路線（test 設定的 9001 掛 9050）" do
    before { load_day }

    it "每個站帶路線 Id 與站位：9050 的 10 站裡己站的站位是 85002，9001 的丙站是 81002" do
      stops = RouteDayStop.where(go_back: 0, seq: 2).order(:route_id).pluck(:route_id, :stop_name, :stop_location_id)
      expect([ RouteDayStop.where(route_id: 9050).count, stops ]).to eq([ 10, [ [ 9001, "丙站", 81002 ], [ 9050, "己站", 85002 ] ] ])
    end

    it "2026-10-19 的 27 趟都是 9001 的，路線日記下成員的名稱" do
      expect([ Trip.distinct.pluck(:route_id), RouteDay.sole.member_names ]).to eq([ [ 9001 ], { "9050" => "測試幹線經己站" } ])
    end
  end

  describe "成員日 2026-10-23" do
    def load_member_day = described_class.new(route_id: 9001, day: Date.new(2026, 10, 23), data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb", out: StringIO.new).call

    it "寫入 3 趟（9050 兩趟、9001 一趟）、2 筆折返停留、13 列趟次站" do
      counts = load_member_day
      expect([ counts.values_at(:trips, :layovers, :trip_stop_counts), Trip.pluck(:route_id).tally ]).to eq([ [ 3, 2, 13 ], { 9050 => 2, 9001 => 1 } ])
    end
  end

  it "回傳寫入的趟次、折返停留、趟次站、兩端、公廁、靜止格、路線軌跡與調度站筆數" do
    expect(load_day).to eq(trips: 27, layovers: 18, trip_stop_counts: 96, trip_stop_speeds: 1, ends: 2, end_toilets: 5, end_cells: 1, shapes: 2, depots: 1)
  end

  describe "寫入後的調度站" do
    before { load_day }

    it "一列：19001、測試客運、測試站、4 台車、27 趟" do
      expect(RouteDayDepot.pluck(:station_id, :provider_name, :station_name, :n_buses, :n_trips)).to eq([ [ 19001, "測試客運", "測試站", 4, 27 ] ])
    end

    it "同一天再載一次：還是恰好一列、id 換了，趟次、折返停留與趟次站的筆數不變" do
      before_reload = [ RouteDayDepot.sole.id, Trip.count, Layover.count, TripStopCount.count ]
      load_day
      expect([ RouteDayDepot.count, RouteDayDepot.sole.id == before_reload.first, [ Trip.count, Layover.count, TripStopCount.count ] ]).to eq([ 1, false, before_reload.drop(1) ])
    end
  end

  describe "寫入後的路線軌跡" do
    before { load_day }

    it "兩個方向各一列、各 5 點，更新時間是 utime 當台北時間" do
      expect(RouteDayShape.order(:go_back).map { [ it.go_back, it.points.size, it.shape_updated_at ] }).to eq(
        [ [ 0, 5, Time.zone.parse("2023-12-29 09:46:21") ], [ 1, 5, Time.zone.parse("2023-12-29 09:48:24") ] ]
      )
    end

    it "方向 0 的點照原本順序，從 (25.05, 121.5) 到 (25.06, 121.5)" do
      expect(RouteDayShape.find_by!(go_back: 0).points.values_at(0, -1)).to eq([ [ 25.05, 121.5 ], [ 25.06, 121.5 ] ])
    end
  end

  describe "靜態快照的路線軌跡檔" do
    let(:out) { StringIO.new }
    let(:root) { Dir.mktmpdir("route-shapes") }

    after { FileUtils.remove_entry(root) }

    # A data root whose raw files and external snapshots are the fixture's and
    # whose static snapshot of 2026-10-19 has the fixture's four other files
    # and, unless `shapes` is nil, a route shapes file holding `shapes`.
    def data_root_with_shapes(shapes)
      %w[bus_event bus_seat_event bus_data external].each { File.symlink(fixture(it), File.join(root, it)) }
      static = File.join(root, "static/2026-10-19").tap { FileUtils.mkdir_p(it) }
      %w[GetRoute.gz GetStop.gz GetPathDetail.gz GetProvider.gz].each { File.symlink(fixture("static/2026-10-19/#{it}"), File.join(static, it)) }
      Zlib::GzipWriter.open(File.join(static, "GetBusShape.gz")) { it.write(JSON.generate(shapes)) } if shapes
      root
    end

    def load_with_shapes(shapes) = described_class.new(route_id: 9001, day:, data_root: data_root_with_shapes(shapes), duckdb: "duckdb", out:).call

    # The fixture's rows of route 9001, with direction 1 latitude and longitude swapped.
    def swapped_direction_1
      rows = JSON.parse(Zlib::GzipReader.open(fixture("static/2026-10-19/GetBusShape.gz"), &:read)).select { it["RouteID"] == 9001 && it["SubRouteID"] == -1 }
      rows.map { it["GoBack"] == 1 ? it.merge("wkt" => "LINESTRING (25.06 121.5003, 25.05 121.5003)") : it }
    end

    it "沒有這個檔：趟次與折返停留照寫，路線軌跡 0 列" do
      expect(load_with_shapes(nil).values_at(:trips, :layovers, :shapes)).to eq([ 27, 18, 0 ])
    end

    it "沒有這個檔：只印一行，點名日期、路線與缺的檔，不再逐方向印" do
      load_with_shapes(nil)
      expect(out.string.lines).to match([ a_string_including("2026-10-19", "9001", "GetBusShape.gz") ])
    end

    it "返程那一列經緯度對調：只存去程，印一行點名日期、路線、返程與原因" do
      load_with_shapes(swapped_direction_1)
      expect([ RouteDayShape.pluck(:go_back), out.string.lines ]).to match([ [ 0 ], [ a_string_including("2026-10-19", "9001", "返程", "out_of_range") ] ])
    end
  end

  describe "靜態快照沒有業者營運基本資料檔（GetProvider.gz）" do
    let(:out) { StringIO.new }
    let(:root) { Dir.mktmpdir("no-providers") }

    after { FileUtils.remove_entry(root) }

    # A data root like the fixture's whose static snapshot of 2026-10-19 has every file but GetProvider.gz.
    def data_root_without_providers
      %w[bus_event bus_seat_event bus_data external].each { File.symlink(fixture(it), File.join(root, it)) }
      static = File.join(root, "static/2026-10-19").tap { FileUtils.mkdir_p(it) }
      %w[GetRoute.gz GetStop.gz GetPathDetail.gz GetBusShape.gz].each { File.symlink(fixture("static/2026-10-19/#{it}"), File.join(static, it)) }
      root
    end

    def load_without_providers = described_class.new(route_id: 9001, day:, data_root: data_root_without_providers, duckdb: "duckdb", out:).call

    it "趟次照寫，只印一行，點名日期、路線與缺的檔" do
      counts = load_without_providers
      expect([ counts[:trips], out.string.lines ]).to match([ 27, [ a_string_including("2026-10-19", "9001", "GetProvider.gz") ] ])
    end

    it "調度站照樣一列，業者與營業站名稱存成空字串" do
      load_without_providers
      expect(RouteDayDepot.pluck(:station_id, :provider_name, :station_name)).to eq([ [ 19001, "", "" ] ])
    end
  end

  it "route_shape.sql 給得出的每一種 issue，loader 都寫得出說明" do
    issues = Rails.root.join("analysis/route_shape.sql").read.scan(/THEN '([a-z_]+)'/).flatten
    expect(issues.sort).to eq(described_class::SHAPE_ISSUES.keys.sort)
  end

  describe "寫入後的兩端" do
    before { load_day }

    def stored_end(go_back)
      RouteDayEnd.find_by!(go_back:).attributes.values_at("location_source", "latitude", "longitude", "n_layovers", "n_located_layovers",
                                                          "n_standstill_records", "end_stop_meters")
    end

    it "戊站端（方向 0）的位置與數字等於 analysis 手算的值" do
      expect(stored_end(0)).to eq([ "standstill", 25.060422, 121.5003, 10, 3, 29, 55.8 ])
    end

    it "甲站端（方向 1）的位置是 E，數字等於 analysis 手算的值" do
      expect(stored_end(1)).to eq([ "standstill", 25.0497, 121.5006, 8, 1, 8, 45.0 ])
    end

    it "公廁掛在各自那一端底下：戊站端三間、甲站端兩間" do
      toilets = RouteDayEndToilet.joins(:route_day_end).order("route_day_ends.go_back", :meters).pluck("route_day_ends.go_back", :name, :meters)
      expect(toilets).to eq([ [ 0, "戊站公園-男廁", 251.7 ], [ 0, "戊站公園-女廁", 253.3 ], [ 0, "戊站加油站-混合廁所", 451.9 ],
                             [ 1, "甲站機關-無障礙廁所", 120.1 ], [ 1, "甲站對面-男廁", 134.4 ] ])
    end

    it "只有一格靜止格，掛在方向 0 那一端底下：(25.0604, 121.5002)、25 筆、3 台車、3 筆折返停留" do
      cells = RouteDayEndCell.joins(:route_day_end).pluck("route_day_ends.go_back", :cell_latitude, :cell_longitude, :n_records, :n_buses, :n_layovers)
      expect(cells).to eq([ [ 0, 25.0604, 121.5002, 25, 3, 3 ] ])
    end

    it "路線日記下用的公廁快照日 2026-10-19" do
      expect(RouteDay.sole.public_toilets_day).to eq(Date.new(2026, 10, 19))
    end
  end

  # Runs the load and swallows the loader's own failure.
  def load_day_ignoring_failure
    load_day
  rescue RouteDayLoader::Error
    nil
  end

  it "寫入途中失敗時丟出錯誤，指出對不上的那張表" do
    load_day.then { break_next_export }
    expect { load_day }.to raise_error(RouteDayLoader::Error, /trip_stop_counts/)
  end

  it "寫入途中失敗後，資料庫裡仍是先前那次的資料" do
    load_day.then { break_next_export }
    expect { load_day_ignoring_failure }.not_to(change { Trip.order(:id).ids })
  end

  describe "站間車速有一列對不到趟次" do
    before { load_day.then { break_next_export("stop_speeds.csv", "TEST-9999,2026-10-19 06:00:00+08:00,1,other,1.0,1") } }

    it "那一天失敗，錯誤訊息指出 trip_stop_speeds" do
      expect { load_day }.to raise_error(RouteDayLoader::Error, /trip_stop_speeds/)
    end

    it "失敗之後，先前那次的站間車速還在" do
      expect { load_day_ignoring_failure }.not_to(change { TripStopSpeed.order(:id).ids })
    end
  end

  it "站牌帶著最近的捷運出入口與距離：9001 去程丙站 0.0 公尺、去程甲站 556.0 公尺；成員路線 9050 的己站 100.7 公尺" do
    load_day
    expect(RouteDayStop.where(go_back: 0, seq: [ 0, 2 ]).order(:route_id, :seq).pluck(:route_id, :nearest_exit_name, :nearest_exit_meters)).to eq(
      [ [ 9001, "丙站捷運出口1", 556.0 ], [ 9001, "丙站捷運出口1", 0.0 ], [ 9050, "丙站捷運出口1", 556.0 ], [ 9050, "丙站捷運出口1", 100.7 ] ]
    )
  end

  describe "出入口快照有兩份（2026-10-20 與 2026-10-22）時" do
    # A data root whose raw files, toilet snapshot and office calendar are the
    # fixture's and whose entrance folder holds the fixture snapshot under two
    # later dates.
    def data_root_with_snapshots(dir)
      link_fixture(dir, "public-toilets", "office-calendar")
      FileUtils.mkdir_p(File.join(dir, "external/taipei-mrt-exits"))
      %w[2026-10-20 2026-10-22].each { FileUtils.cp(fixture("external/taipei-mrt-exits/2026-10-19.csv"), File.join(dir, "external/taipei-mrt-exits/#{it}.csv")) }
      dir
    end

    it "用檔名日期最新的那一份，並記在路線日上" do
      Dir.mktmpdir { described_class.new(route_id: 9001, day:, data_root: data_root_with_snapshots(it), duckdb: "duckdb").call }
      expect(RouteDay.sole.mrt_exits_day).to eq(Date.new(2026, 10, 22))
    end
  end

  describe "公廁快照有兩份（2026-10-20 與少了甲站對面的 2026-10-23）時" do
    # A data root whose raw files, entrance snapshot and office calendar are
    # the fixture's, with the fixture toilet snapshot as 2026-10-20 and the
    # same without 甲站對面-男廁 as 2026-10-23.
    def data_root_with_toilet_snapshots(dir)
      link_fixture(dir, "taipei-mrt-exits", "office-calendar")
      FileUtils.mkdir_p(File.join(dir, "external/public-toilets"))
      lines = File.readlines(fixture("external/public-toilets/2026-10-19.csv"))
      File.write(File.join(dir, "external/public-toilets/2026-10-20.csv"), lines.join)
      File.write(File.join(dir, "external/public-toilets/2026-10-23.csv"), lines.reject { it.include?("甲站對面-男廁") }.join)
      dir
    end

    it "公廁來自檔名日期最新的那一份，路線日記下 2026-10-23" do
      Dir.mktmpdir { described_class.new(route_id: 9001, day:, data_root: data_root_with_toilet_snapshots(it), duckdb: "duckdb").call }
      expect([ RouteDay.sole.public_toilets_day, RouteDayEndToilet.count ]).to eq([ Date.new(2026, 10, 23), 4 ])
    end
  end

  describe "有捷運出入口快照與辦公日曆、沒有公廁快照時" do
    let(:root) { link_fixture(Dir.mktmpdir("no-toilets"), "taipei-mrt-exits", "office-calendar") }

    after { FileUtils.remove_entry(root) }

    def load_without_toilets = described_class.new(route_id: 9001, day:, data_root: root, duckdb: "duckdb").call

    def load_without_toilets_ignoring_failure
      load_without_toilets
    rescue RouteDayLoader::Error
      nil
    end

    it "失敗，說要先跑 bin/rails external:public_toilets" do
      expect { load_without_toilets }.to raise_error(RouteDayLoader::Error, %r{bin/rails external:public_toilets})
    end

    it "什麼都不寫" do
      expect { load_without_toilets_ignoring_failure }.not_to(change { stored_counts })
    end
  end

  describe "路線還沒寫進 config/route_page.yml 時" do
    let(:out) { StringIO.new }

    before { allow(RoutePage).to receive(:route_ids).and_return([]) }

    def load_unconfigured = described_class.new(route_id: 9001, day:, data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb", out:).call

    it "趟次、折返停留、趟次站、站間車速、路線軌跡與調度站照寫，兩端、公廁與靜止格都是 0 列" do
      expect(load_unconfigured).to eq(trips: 27, layovers: 18, trip_stop_counts: 96, trip_stop_speeds: 1, ends: 0, end_toilets: 0, end_cells: 0, shapes: 2, depots: 1)
    end

    it "資料庫裡兩端、公廁與靜止格都沒有列" do
      load_unconfigured
      expect([ RouteDayEnd.count, RouteDayEndToilet.count, RouteDayEndCell.count ]).to eq([ 0, 0, 0 ])
    end

    it "輸出多一行，說路線 9001 還沒有設定、沒有設施的列" do
      load_unconfigured
      expect(out.string).to include("9001").and include("沒有設定")
    end
  end

  describe "設定裡的 9001 只有方向 0 時" do
    before { allow(RoutePage).to receive(:ends) { |route_id| RoutePage::Ends.from_config({ 0 => "stop" }, route_id:) } }

    it "那一天失敗，訊息指出路線與缺的方向" do
      expect { load_day }.to raise_error(RouteDayLoader::Error, /route 9001, direction 1/)
    end

    it "什麼都不寫" do
      expect { load_day_ignoring_failure }.not_to(change { stored_counts })
    end
  end

  it "fixture 的 2026 日曆裡 10-19 是平日：路線日是 weekday、沒有備註、日曆快照日 2026-10-19" do
    load_day
    expect(RouteDay.sole.attributes.values_at("day_type", "day_note", "office_calendar_day")).to eq([ "weekday", nil, Date.new(2026, 10, 19) ])
  end

  describe "日曆把 2026-10-19 標成「補假」的假日時" do
    # A data root whose raw files, entrance snapshot and toilet snapshot are
    # the fixture's and whose 2026 calendar marks 2026-10-19 as the holiday 補假.
    def data_root_with_holiday(dir)
      link_fixture(dir, "taipei-mrt-exits", "public-toilets")
      FileUtils.mkdir_p(File.join(dir, "external/office-calendar/2026"))
      calendar = File.read(fixture("external/office-calendar/2026/2026-10-19.csv"))
      File.write(File.join(dir, "external/office-calendar/2026/2026-10-19.csv"), calendar.sub("20261019,一,0,", "20261019,一,2,補假"))
      dir
    end

    let(:holiday_root) { data_root_with_holiday(Dir.mktmpdir("holiday")) }

    after { FileUtils.remove_entry(holiday_root) }

    def load_holiday = described_class.new(route_id: 9001, day:, data_root: holiday_root, duckdb: "duckdb").call

    it "路線日是 holiday、備註是補假" do
      load_holiday
      expect(RouteDay.sole.attributes.values_at("day_type", "day_note")).to eq([ "holiday", "補假" ])
    end

    it "TEST-0002 23:40 發車、隔天 00:50 到站的那一趟，存在日型別是假日的 10-19 路線日底下" do
      load_holiday
      expect(Trip.find_by!(bus_id: "TEST-0002", start_time: Time.zone.parse("2026-10-19 23:40")).route_day.attributes.values_at("day", "day_type")).to eq([ day, "holiday" ])
    end
  end

  it "時刻以台北時間存入：TEST-0001 的第一趟 06:00 發車" do
    load_day
    expect(Trip.where(bus_id: "TEST-0001").minimum(:start_time)).to eq(Time.zone.parse("2026-10-19 06:00"))
  end

  describe "DuckDB 失敗時（fixture 沒有 2026-10-30）" do
    let(:day) { Date.new(2026, 10, 30) }

    it "丟出錯誤，訊息帶出 DuckDB 的標準錯誤" do
      expect { load_day }.to raise_error(RouteDayLoader::Error, /2026-10-30/)
    end

    it "什麼都不寫" do
      expect { load_day_ignoring_failure }.not_to(change { stored_counts })
    end
  end
end
