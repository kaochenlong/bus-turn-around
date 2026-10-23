require "spec_helper"
require "fileutils"
require_relative "../support/duckdb"
require_relative "../../lib/analysis_run"

RSpec.describe "analysis/derived_export.sql" do
  # Runs every stage, mrt_overlap.sql, turnaround_facilities.sql and
  # derived_export.sql on the fixture day with both ends stopping, returns the
  # derived CSV files as { name => bytes }. `public_toilets_path` replaces the
  # fixture's toilet snapshot.
  def export(public_toilets_path: fixture_path("external/public-toilets/2026-10-19.csv"))
    Dir.mktmpdir("derived-export") do |dir|
      derived_dir = File.join(dir, "derived").tap { FileUtils.mkdir_p(it) }
      variables = DuckdbHelpers::FIXTURE_VARIABLES.merge(
        inspect_dir: dir, derived_dir:, mrt_exits_path: fixture_path("external/taipei-mrt-exits/2026-10-19.csv"), mrt_exits_day: Date.new(2026, 10, 19),
        public_toilets_path:, public_toilets_day: Date.new(2026, 10, 19), end_nature_0: "stop", end_nature_1: "stop"
      )
      AnalysisRun.run("duckdb", variables, extra_files: %w[mrt_overlap.sql turnaround_facilities.sql derived_export.sql])
      Dir.children(derived_dir).sort.to_h { [ it, File.binread(File.join(derived_dir, it)) ] }
    end
  end

  def fixture_path(path) = File.join(DuckdbHelpers::FIXTURE_DATA, path)

  let(:files) { export }
  let(:expected_headers) do
    { "end_cells.csv" => "go_back,cell_latitude,cell_longitude,n_records,n_buses,n_layovers",
      "end_toilets.csv" => "go_back,name,category,address,latitude,longitude,meters",
      "ends.csv" => "go_back,end_seq,end_stop_name,end_latitude,end_longitude,location_source,latitude,longitude," \
                    "n_layovers,n_located_layovers,n_standstill_records,end_stop_meters",
      "layovers.csv" => "bus_id,go_back,end_time,next_start_time",
      "route_day.csv" => "route_id,day,route_name,departure,destination,static_day,mrt_exits_day,public_toilets_day",
      "stops.csv" => "go_back,seq,stop_name,latitude,longitude,nearest_exit_name,nearest_exit_meters",
      "trip_stop_counts.csv" => "bus_id,start_time,seq,on_board",
      "trips.csv" => "bus_id,path_attribute_id,go_back,band,start_time,end_time,first_seq,last_seq,n_events," \
                     "n_stops_observed,completeness,start_from_arrival,end_from_departure" }
  end

  def rows(name, from = files) = from.fetch(name).dup.force_encoding(Encoding::UTF_8).lines.drop(1).map(&:chomp)

  it "寫出八個檔，欄位名照固定順序" do
    expect(files.transform_values { it.lines.first.chomp }).to eq(expected_headers)
  end

  it "趟次 27 列、折返停留 18 列、有人數的趟次站 96 列、站序 10 列、路線日 1 列" do
    counts = %w[trips.csv layovers.csv trip_stop_counts.csv stops.csv route_day.csv].map { rows(it).size }
    expect(counts).to eq([ 27, 18, 96, 10, 1 ])
  end

  it "趟次依車牌與起點排序，時刻帶 +08:00：第一列是 TEST-0001 06:00 那趟，時段是其餘" do
    expect(rows("trips.csv").first.split(",").values_at(0, 3, 4, 5)).to eq(
      [ "TEST-0001", "other", "2026-10-19 06:00:00+08:00", "2026-10-19 06:50:00+08:00" ]
    )
  end

  it "路線日帶路線 Id、資料日、路線名稱、起迄、靜態快照日、捷運出入口快照日與公廁快照日" do
    expect(rows("route_day.csv").first).to eq("9001,2026-10-19,測試幹線,甲站,戊站,2026-10-19,2026-10-19,2026-10-19")
  end

  it "站牌帶經緯度與最近的捷運出入口：去程丙站在出入口上，0.0 公尺" do
    expect(rows("stops.csv")[2]).to eq("0,2,丙站,25.055,121.5,丙站捷運出口1,0.0")
  end

  it "兩端各一列，照方向排：末站、位置的來源與座標、三個查核數字與靜止回報筆數" do
    expect(rows("ends.csv")).to eq(
      [ "0,4,戊站,25.06,121.5,standstill,25.060422,121.5003,10,3,29,55.8", "1,9,甲站,25.05,121.5003,standstill,25.0497,121.5006,8,1,8,45.0" ]
    )
  end

  it "公廁一間一列，照方向、公尺排，帶逗號的地址加引號" do
    expect(rows("end_toilets.csv")).to eq(
      [ "0,戊站公園-男廁,公園,臺北市測試區戊路2號,25.062686,121.5003,251.7", "0,戊站公園-女廁,公園,臺北市測試區戊路2號,25.0627,121.5003,253.3",
        "0,戊站加油站-混合廁所,商業營業場所,\"臺北市測試區戊路1號, 2樓\",25.064486,121.5003,451.9",
        "1,甲站機關-無障礙廁所,民眾洽公場所,臺北市測試區甲路1號,25.04862,121.5006,120.1", "1,甲站對面-男廁,交通,臺北市測試區甲路2號,25.04862,121.5012,134.4" ]
    )
  end

  it "靜止格只有戊站端那一格" do
    expect(rows("end_cells.csv")).to eq([ "0,25.0604,121.5002,25,3,3" ])
  end

  # A toilet snapshot in `dir` with two toilets at different addresses, 120.0
  # metres north and south of the direction 1 location E, 甲公廁 listed first.
  def tied_toilets(dir)
    File.join(dir, "toilets.csv").tap do |path|
      File.write(path, "#{File.readlines(fixture_path('external/public-toilets/2026-10-19.csv')).first}" \
                       "63000,63000040,甲里,A1,甲公廁,測試路4號,甲,25.050779186,121.5006,優等級,公園,男廁所,甲,0\n" \
                       "63000,63000040,甲里,A2,乙公廁,測試路5號,乙,25.048620814,121.5006,優等級,公園,男廁所,乙,0\n")
    end
  end

  it "距離相同的兩間照名稱排：甲站端位置 120.0 公尺的甲公廁與乙公廁，乙公廁在前" do
    stored = Dir.mktmpdir { rows("end_toilets.csv", export(public_toilets_path: tied_toilets(it))) }
    expect(stored.map { it.split(",").values_at(1, 6) }).to eq([ %w[乙公廁 120.0], %w[甲公廁 120.0] ])
  end

  it "連跑兩次，八個檔位元組相同" do
    expect(export).to eq(files)
  end
end
