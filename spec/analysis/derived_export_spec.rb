require "spec_helper"
require "fileutils"
require_relative "../support/duckdb"
require_relative "../../lib/analysis_run"

RSpec.describe "analysis/derived_export.sql" do
  # Runs every stage, mrt_overlap.sql and derived_export.sql on the fixture
  # day, returns the derived CSV files as { name => bytes }.
  def export
    Dir.mktmpdir("derived-export") do |dir|
      derived_dir = File.join(dir, "derived").tap { FileUtils.mkdir_p(it) }
      variables = DuckdbHelpers::FIXTURE_VARIABLES.merge(inspect_dir: dir, derived_dir:, mrt_exits_path:, mrt_exits_day: Date.new(2026, 10, 19))
      AnalysisRun.run("duckdb", variables, extra_files: %w[mrt_overlap.sql derived_export.sql])
      Dir.children(derived_dir).sort.to_h { [ it, File.binread(File.join(derived_dir, it)) ] }
    end
  end

  let(:files) { export }
  let(:mrt_exits_path) { File.join(DuckdbHelpers::FIXTURE_DATA, "external/taipei-mrt-exits/2026-10-19.csv") }
  let(:expected_headers) do
    { "layovers.csv" => "bus_id,go_back,end_time,next_start_time",
      "route_day.csv" => "route_id,day,route_name,departure,destination,static_day,mrt_exits_day",
      "stops.csv" => "go_back,seq,stop_name,latitude,longitude,nearest_exit_name,nearest_exit_meters",
      "trip_stop_counts.csv" => "bus_id,start_time,seq,on_board",
      "trips.csv" => "bus_id,path_attribute_id,go_back,band,start_time,end_time,first_seq,last_seq,n_events," \
                     "n_stops_observed,completeness,start_from_arrival,end_from_departure" }
  end

  def rows(name) = files.fetch(name).dup.force_encoding(Encoding::UTF_8).lines.drop(1)

  it "寫出五個檔，欄位名照固定順序" do
    expect(files.transform_values { it.lines.first.chomp }).to eq(expected_headers)
  end

  it "趟次 27 列、折返停留 19 列、有人數的趟次站 96 列、站序 10 列、路線日 1 列" do
    counts = %w[trips.csv layovers.csv trip_stop_counts.csv stops.csv route_day.csv].map { rows(it).size }
    expect(counts).to eq([ 27, 19, 96, 10, 1 ])
  end

  it "趟次依車牌與起點排序，時刻帶 +08:00：第一列是 TEST-0001 06:00 那趟，時段是其餘" do
    expect(rows("trips.csv").first.split(",").values_at(0, 3, 4, 5)).to eq(
      [ "TEST-0001", "other", "2026-10-19 06:00:00+08:00", "2026-10-19 06:50:00+08:00" ]
    )
  end

  it "路線日帶路線 Id、資料日、路線名稱、起迄、靜態快照日與捷運出入口快照日" do
    expect(rows("route_day.csv").first.chomp).to eq("9001,2026-10-19,測試幹線,甲站,戊站,2026-10-19,2026-10-19")
  end

  it "站牌帶經緯度與最近的捷運出入口：去程丙站在出入口上，0.0 公尺" do
    expect(rows("stops.csv")[2].chomp).to eq("0,2,丙站,25.055,121.5,丙站捷運出口1,0.0")
  end

  it "連跑兩次，五個檔位元組相同" do
    expect(export).to eq(files)
  end
end
