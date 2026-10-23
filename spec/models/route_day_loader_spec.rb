require "rails_helper"
require_relative "../support/duckdb"

RSpec.describe RouteDayLoader, :duckdb, type: :model do
  let(:day) { Date.new(2026, 10, 19) }

  def load_day = described_class.new(route_id: 9001, day:, data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb").call

  def stored_counts
    [ Trip.count, Layover.count, TripStopCount.count, RouteDayStop.count, RouteDay.count, RouteDayEnd.count, RouteDayEndToilet.count, RouteDayEndCell.count ]
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

  # Makes the next export write a trip stop count whose trip does not exist, so
  # the load fails after the old day has been deleted inside the transaction.
  def break_next_export
    allow(AnalysisRun).to receive(:run).and_wrap_original do |original, *args, **options|
      original.call(*args, **options).tap do
        File.open(File.join(args[1].fetch(:derived_dir), "trip_stop_counts.csv"), "a") { it.puts("TEST-9999,2026-10-19 06:00:00+08:00,0,1") }
      end
    end
  end

  it "fixture 2026-10-19 寫入兩次，趟次 27、折返停留 18、趟次站 96、站序 10、路線日 1、兩端 2、公廁 5、靜止格 1，第二次後不變" do
    load_day
    expect { load_day }.not_to(change { stored_counts }.from([ 27, 18, 96, 10, 1, 2, 5, 1 ]))
  end

  it "回傳寫入的趟次、折返停留、趟次站、兩端、公廁與靜止格筆數" do
    expect(load_day).to eq(trips: 27, layovers: 18, trip_stop_counts: 96, ends: 2, end_toilets: 5, end_cells: 1)
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

  it "站牌帶著最近的捷運出入口與距離：去程丙站 0.0 公尺、去程甲站 556.0 公尺" do
    load_day
    expect(RouteDayStop.where(go_back: 0, seq: [ 0, 2 ]).order(:seq).pluck(:nearest_exit_name, :nearest_exit_meters)).to eq(
      [ [ "丙站捷運出口1", 556.0 ], [ "丙站捷運出口1", 0.0 ] ]
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

    it "趟次、折返停留與趟次站照寫，兩端、公廁與靜止格都是 0 列" do
      expect(load_unconfigured).to eq(trips: 27, layovers: 18, trip_stop_counts: 96, ends: 0, end_toilets: 0, end_cells: 0)
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
