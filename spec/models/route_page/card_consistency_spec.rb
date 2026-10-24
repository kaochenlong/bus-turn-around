require "rails_helper"
require_relative "../../support/duckdb"

# The route page recomputes its numbers in PostgreSQL from the stored trips.
# On the same input they must equal the health card's, or a definition has
# drifted on the way into the database. The member day runs the page route
# with its member route, the way derived:load and bin/health-card --also-route
# do.
RSpec.describe "路線頁的數字與健檢卡一致", :duckdb, type: :model do
  def card_for(**variables)
    Dir.mktmpdir { |dir| AnalysisRun.run("duckdb", DuckdbHelpers::FIXTURE_VARIABLES.merge(inspect_dir: dir, **variables)).first.fetch("card") }
  end

  # Loads the day the way bin/rails derived:load does and returns the stored route days.
  def load_through_command(day)
    env = { "TURNAROUND_DATA" => DuckdbHelpers::FIXTURE_DATA, "ROUTE" => "9001", "DAY" => day.iso8601, "PATH" => ENV.fetch("PATH") }
    raise "derived:load failed" unless DerivedLoadCommand.new(env, out: StringIO.new).run.zero?

    RouteDay.where(route_id: 9001, day:)
  end

  shared_examples "跟卡上的數字一致" do
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

    it "折返停留分組的下界，以及各方向每組的筆數" do
      layovers = card.fetch("layovers")
      expected = [ layovers["bin_lower_bounds"], layovers["distribution"].reject { it["go_back"].nil? }.map { it.values_at("go_back", "bin_counts") } ]
      actual = [ RoutePage::LayoverDistribution::BIN_LOWER_BOUNDS, RoutePage::LayoverDistribution.new(route_days).directions.map { [ it.go_back, it.counts ] } ]
      expect(actual).to eq(expected)
    end

    it "載客剖面每格的趟數、中位數與 p90，含站名" do
      expected = card.dig("profile", "rows").map { it.values_at("go_back", "band", "seq", "stop_name", "n_trips", "median", "p90") }
      actual = RoutePage::LoadProfile.new(route_days).rows.map { [ it.go_back, it.band, it.seq, it.stop_name, it.n_trips, it.median, it.p90 ] }
      expect(actual).to match_array(expected)
    end
  end

  describe "fixture 日 2026-10-19" do
    let(:day) { Date.new(2026, 10, 19) }
    let(:card) { card_for }
    let(:route_days) do
      RouteDayLoader.new(route_id: 9001, day:, data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb").call
      RouteDay.where(route_id: 9001, day:)
    end

    it_behaves_like "跟卡上的數字一致"
  end

  describe "成員日 2026-10-23，9001 掛 9050：derived:load ROUTE=9001 對 bin/health-card --also-route 9050" do
    let(:day) { Date.new(2026, 10, 23) }
    let(:card) { card_for(member_route_ids: [ 9001, 9050 ], day:, static_day: day) }
    let(:route_days) { load_through_command(day) }

    it_behaves_like "跟卡上的數字一致"

    it "卡上是 3 趟、3 趟完整、兩個方向各一筆 10.0 分鐘的折返停留，頁面也是" do
      stats = RoutePage::LayoverStats.new(route_days).rows.map { [ it.go_back, it.n_layovers, it.percentiles[1] ] }
      expect([ card.dig("trips", "total"), card.dig("quality", "completeness", "complete"), stats ]).to eq([ 3, 3, [ [ 0, 1, 10.0 ], [ 1, 1, 10.0 ] ] ])
    end
  end
end
