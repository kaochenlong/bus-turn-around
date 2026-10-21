require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/mrt_overlap.sql" do
  let(:fixture_exits) { File.join(DuckdbHelpers::FIXTURE_DATA, "external/taipei-mrt-exits/2026-10-19.csv") }

  # Rows of stop_mrt_distances after every stage and mrt_overlap.sql, with
  # the given entrance snapshot.
  def distances(exits_path)
    run_sql_stages(through: "50_quality", mrt_exits_path: exits_path,
                   query: "#{File.read(File.join(DuckdbHelpers::ANALYSIS_DIR, 'mrt_overlap.sql'))}\n" \
                          "SELECT go_back, seq, nearest_exit_name, nearest_exit_meters FROM stop_mrt_distances ORDER BY go_back, seq")
  end

  it "fixture 每站最近的出入口都是丙站捷運出口1，距離等於 README 手算的值（容許 0.1 公尺）" do
    expected = [ 556.0, 278.0, 0.0, 278.0, 556.0, 556.8, 279.6, 30.2, 279.6, 556.8 ]
    rows = distances(fixture_exits)
    expect([ rows.map { it["nearest_exit_name"] }.uniq, rows.map { it["nearest_exit_meters"] } ]).to match(
      [ [ "丙站捷運出口1" ], expected.map { a_value_within(0.1).of(it) } ]
    )
  end

  it "距離約 111 公尺的出入口比約 334 公尺的近：甲站的最近出入口是 A" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "exits.csv")
      File.write(path, "項次,出入口名稱,出入口編號,經度,緯度,是否為無障礙用\n1,A,1,121.5,25.051,是\n2,B,1,121.5,25.047,是\n")
      expect(distances(path).first.values_at("nearest_exit_name", "nearest_exit_meters")).to match([ "A", a_value_within(0.1).of(111.2) ])
    end
  end

  it "站牌帶著經緯度：去程甲站在 25.05、121.5" do
    row = run_sql_stages(through: "50_quality", mrt_exits_path: fixture_exits,
                         query: "#{File.read(File.join(DuckdbHelpers::ANALYSIS_DIR, 'mrt_overlap.sql'))}\nSELECT latitude, longitude FROM stop_mrt_distances WHERE seq = 0")
    expect(row).to eq([ { "latitude" => 25.05, "longitude" => 121.5 } ])
  end
end
