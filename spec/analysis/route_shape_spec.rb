require "spec_helper"
require "json"
require "tmpdir"
require_relative "../support/duckdb"

# analysis/route_shape.sql reads only params.sql and the variables route_id and
# bus_shape_path, so these examples run it without the stages: on the route
# shapes file of the fixture snapshot, and on files written for one example,
# where route 9001's direction 0 is the fixture's and its direction 1 varies.
RSpec.describe "analysis/route_shape.sql" do
  let(:fixture_file) { File.join(DuckdbHelpers::FIXTURE_DATA, "static/2026-10-19/GetBusShape.gz") }

  # The two rows of route_shapes for the route shapes file at `path`, by direction.
  def route_shapes(path)
    query = "#{File.read(File.join(DuckdbHelpers::ANALYSIS_DIR, 'route_shape.sql'))}\n" \
            "SELECT go_back, strftime(shape_updated_at, '%Y-%m-%d %H:%M:%S') AS updated_at, points, issue FROM route_shapes ORDER BY go_back"
    run_sql_stages(through: "params", query:, bus_shape_path: path)
  end

  # route_shapes for a file holding `rows`, an array the way the file has it.
  def shapes_of(rows)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "shapes.json").tap { File.write(it, JSON.generate(rows)) }
      route_shapes(path)
    end
  end

  # A row of route 9001 with the keys of the real file.
  def shape_row(go_back, wkt, utime: "2023-12-29 09:48:24", sub_route_id: -1)
    { "UniRouteId" => "0000900100", "RouteID" => 9001, "SubRouteID" => sub_route_id, "wkt" => wkt, "utime" => utime, "GoBack" => go_back }
  end

  def fixture_direction_0
    shape_row(0, "LINESTRING (121.50000012345678 25.04999987654321, 121.5 25.0525, 121.5 25.055, 121.5 25.0575, 121.5 25.06)",
              utime: "2023-12-29 09:46:21")
  end

  describe "fixture 的靜態快照" do
    let(:shapes) { route_shapes(fixture_file) }

    it "兩個方向各 5 點、沒有 issue：路線 9100 與附屬路線 99001 的列比較新，也沒有留下" do
      expect(shapes.map { [ it["go_back"], it["points"].size, it["issue"] ] }).to eq([ [ 0, 5, nil ], [ 1, 5, nil ] ])
    end

    it "方向 0 的點照原本順序，取到小數 6 位：第一點原本 14 位小數，是 (25.05, 121.5)" do
      expect(shapes.first["points"]).to eq([ [ 25.05, 121.5 ], [ 25.0525, 121.5 ], [ 25.055, 121.5 ], [ 25.0575, 121.5 ], [ 25.06, 121.5 ] ])
    end

    it "方向 1 從 (25.06, 121.5003) 到 (25.05, 121.5003)" do
      expect(shapes.last["points"].values_at(0, -1)).to eq([ [ 25.06, 121.5003 ], [ 25.05, 121.5003 ] ])
    end

    it "更新時間照 utime：2023-12-29 09:46:21 與 09:48:24" do
      expect(shapes.map { it["updated_at"] }).to eq([ "2023-12-29 09:46:21", "2023-12-29 09:48:24" ])
    end
  end

  it "內容是 [] 的檔：兩個方向都沒有點，issue 都是 no_row" do
    expect(shapes_of([]).map { it.values_at("points", "issue") }).to eq([ [ nil, "no_row" ] ] * 2)
  end

  describe "方向 1 那一列不能用：方向 0 照存，方向 1 沒有點，issue 寫原因" do
    [
      [ "沒有方向 1 的列", nil, nil, "no_row" ],
      [ "MULTILINESTRING", "MULTILINESTRING ((121.5003 25.06, 121.5003 25.05))", "2023-12-29 09:48:24", "not_linestring" ],
      [ "只有 1 點", "LINESTRING (121.5003 25.06)", "2023-12-29 09:48:24", "too_few_points" ],
      [ "經緯度對調", "LINESTRING (25.06 121.5003, 25.05 121.5003)", "2023-12-29 09:48:24", "out_of_range" ],
      [ "utime 讀不出來", "LINESTRING (121.5003 25.06, 121.5003 25.05)", "unknown", "no_update_time" ]
    ].each do |label, wkt, utime, issue|
      it "#{label}：#{issue}" do
        rows = [ fixture_direction_0, (shape_row(1, wkt, utime:) if wkt) ].compact
        expect(shapes_of(rows).map { [ it["points"]&.size, it["issue"] ] }).to eq([ [ 5, nil ], [ nil, issue ] ])
      end
    end

    it "有一點不是兩個數字：not_linestring" do
      rows = [ fixture_direction_0, shape_row(1, "LINESTRING (121.5003 25.06, 甲 25.05)") ]
      expect(shapes_of(rows).last.values_at("points", "issue")).to eq([ nil, "not_linestring" ])
    end
  end

  it "剛好 2 點，落在範圍的邊上 (20, 118) 與 (27, 123)：照存" do
    rows = [ fixture_direction_0, shape_row(1, "LINESTRING (118 20, 123 27)") ]
    expect(shapes_of(rows).last.values_at("points", "issue")).to eq([ [ [ 20.0, 118.0 ], [ 27.0, 123.0 ] ], nil ])
  end

  it "同一個方向兩列都能用：留 utime 較新的那一列，issue 是 duplicate_rows" do
    newer = shape_row(0, "LINESTRING (121.5 25.05, 121.5 25.06)", utime: "2024-01-05 10:00:00")
    expect(shapes_of([ fixture_direction_0, newer ]).first.values_at("points", "updated_at", "issue"))
      .to eq([ [ [ 25.05, 121.5 ], [ 25.06, 121.5 ] ], "2024-01-05 10:00:00", "duplicate_rows" ])
  end

  it "同一個方向一列能用、一列比較新但不能用：留能用的那一列，issue 也是 duplicate_rows" do
    broken = shape_row(0, "LINESTRING (121.5 25.05)", utime: "2024-01-05 10:00:00")
    expect(shapes_of([ fixture_direction_0, broken ]).first.values_at("updated_at", "issue")).to eq([ "2023-12-29 09:46:21", "duplicate_rows" ])
  end
end
