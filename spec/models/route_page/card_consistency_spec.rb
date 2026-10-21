require "rails_helper"
require_relative "../../support/duckdb"

# The route page recomputes its numbers in PostgreSQL from the stored trips.
# On the same input they must equal the health card's, or a definition has
# drifted on the way into the database.
RSpec.describe "路線頁的數字與健檢卡一致", :duckdb, type: :model do
  let(:day) { Date.new(2026, 10, 19) }
  let(:card) do
    Dir.mktmpdir { |dir| AnalysisRun.run("duckdb", DuckdbHelpers::FIXTURE_VARIABLES.merge(inspect_dir: dir)).first.fetch("card") }
  end
  let(:route_days) do
    RouteDayLoader.new(route_id: 9001, day:, data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb").call
    RouteDay.where(route_id: 9001, day:)
  end

  it "趟數與完整趟數" do
    summary = RoutePage::Summary.new(route_days)
    expect([ summary.trips, summary.complete_trips ]).to eq([ card.dig("trips", "total"), card.dig("quality", "completeness", "complete") ])
  end

  it "各方向折返停留的筆數、p10、p50、p90 與不到 15 分鐘的比例" do
    expected = card.dig("layovers", "distribution").reject { it["go_back"].nil? }
                   .map { it.values_at("go_back", "n_layovers", "percentiles", "short_share") }
    actual = RoutePage::LayoverStats.new(route_days).rows.map { [ it.go_back, it.n_layovers, it.percentiles, it.short_share ] }
    expect(actual).to eq(expected)
  end

  it "載客剖面每格的趟數、中位數與 p90，含站名" do
    expected = card.dig("profile", "rows").map { it.values_at("go_back", "band", "seq", "stop_name", "n_trips", "median", "p90") }
    actual = RoutePage::LoadProfile.new(route_days).rows.map { [ it.go_back, it.band, it.seq, it.stop_name, it.n_trips, it.median, it.p90 ] }
    expect(actual).to match_array(expected)
  end
end
