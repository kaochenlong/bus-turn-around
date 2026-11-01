require "spec_helper"
require "open3"
require_relative "../support/duckdb"
require_relative "../../lib/analysis_run"

# Whether the duckdb on PATH can load the spatial extension, tried once for
# the whole run: the extension is installed per machine, so the examples below
# are pending wherever it is not.
module SpatialExtension
  def self.available?
    return @available if defined?(@available)

    _stdout, _stderr, status = Open3.capture3("duckdb", *DuckdbHelpers::DUCKDB_FLAGS, stdin_data: "LOAD spatial;")
    @available = status.success?
  end
end

RSpec.describe "analysis/stop_district_snapshot.sql" do
  before do
    skip DuckdbHelpers::SKIP_MESSAGE unless DuckdbHelpers.duckdb_on_path?
    skip "這台機器沒有 DuckDB 的 spatial 延伸，先跑 duckdb -c \"INSTALL spatial\"" unless SpatialExtension.available?
  end

  let(:shapefile) { File.join(DuckdbHelpers::FIXTURE_DATA, "external/town-boundaries/TOWN_MOI_TEST.shp") }
  let(:fixture_snapshot) { File.read(File.join(DuckdbHelpers::FIXTURE_DATA, "external/stop-districts/2026-10-19.csv")) }

  # The printed counts and the written file, for the stop list of a fixture
  # static day.
  def run_snapshot(static_day)
    Dir.mktmpdir("stop-district-snapshot") do |dir|
      output = File.join(dir, "out.csv")
      stops = File.join(DuckdbHelpers::FIXTURE_DATA, "static", static_day, "GetStop.gz")
      rows = AnalysisRun.run("duckdb", { shapefile_path: shapefile, stops_path: stops, output_path: output },
                             extra_files: [ "stop_district_snapshot.sql" ], stages: false)
      [ rows, File.read(output) ]
    end
  end

  it "fixture 的區界檔對 2026-10-23 的 GetStop.gz：16 個站位、15 個判到區，寫出的 CSV 就是 fixture 快照那 15 列，85007 判不到" do
    expect(run_snapshot("2026-10-23")).to eq([ [ { "n_locations" => 16, "n_assigned" => 15 } ], fixture_snapshot ])
  end
end
