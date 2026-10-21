require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/30_layovers.sql" do
  def layover_rows(query) = run_sql_stages(through: "30_layovers", query:)

  def from_trips(trips, query) = layover_rows("#{replace_trips_sql(trips)}\n#{query}")

  # Six complete trips of one vehicle with layovers of 4, 8, 12, 20 and 45 minutes.
  let(:spaced_trips) do
    [ %w[06:00 06:30], %w[06:34 07:00], %w[07:08 07:30], %w[07:42 08:00], %w[08:20 08:30], %w[09:15 09:45] ]
      .each_with_index.map { |(start, finish), index| { bus_id: "TEST-0001", start:, finish:, go_back: index % 2 } }
  end

  describe "fixture 的 2026-10-19" do
    it "折返停留跟 fixture README 手算的 16 筆一致，每台車依序" do
      rows = layover_rows("SELECT bus_id, list(minutes ORDER BY end_time) AS minutes FROM layovers GROUP BY bus_id ORDER BY bus_id")
      expect(rows.to_h { [ it["bus_id"], it["minutes"] ] }).to eq(
        "TEST-0001" => [ 10.0, 12.0, 13.0, 10.0, 56.0, 21.0, 25.0, 85.0 ],
        "TEST-0002" => [ 12.0, 302.0, 12.0, 282.0 ], "TEST-0003" => [ 15.0, 17.0 ], "TEST-0004" => [ 17.0, 12.0 ]
      )
    end

    it "08:30 結束的完整趟次與 08:42 開始的下一趟，折返停留 12.0 分鐘" do
      rows = layover_rows("SELECT minutes FROM layovers WHERE bus_id = 'TEST-0001' AND end_time = TIMESTAMP '2026-10-19 08:30:00'")
      expect(rows).to eq([ { "minutes" => 12.0 } ])
    end

    it "有一趟不完整的配對 7 組不算，下一趟是別的路線與差值為負的都是 0" do
      expect(layover_rows("SELECT incomplete, other_route, negative FROM layover_exclusions")).to eq(
        [ { "incomplete" => 7, "other_route" => 0, "negative" => 0 } ]
      )
    end

    it "每台車當天最後一趟沒有折返停留" do
      rows = layover_rows(<<~SQL)
        SELECT count(*) AS n FROM layovers l JOIN trips t USING (trip_id)
        WHERE t.start_time = (SELECT max(start_time) FROM trips WHERE bus_id = t.bus_id)
      SQL
      expect(rows).to eq([ { "n" => 0 } ])
    end

    it "按結束那趟的方向分列：去程 9 筆、中位數 13.0，返程 7 筆、中位數 21.0" do
      rows = layover_rows(<<~SQL)
        SELECT go_back, n_layovers, percentiles[2] AS p50 FROM layover_distribution WHERE go_back IS NOT NULL ORDER BY go_back
      SQL
      expect(rows).to eq([ { "go_back" => 0, "n_layovers" => 9, "p50" => 13.0 }, { "go_back" => 1, "n_layovers" => 7, "p50" => 21.0 } ])
    end
  end

  describe "灌入的趟次" do
    it "完整趟次 08:30 結束、下一趟 08:28 開始時不算，負值配對 1 組" do
      trips = [ { bus_id: "TEST-0001", start: "08:00", finish: "08:30" }, { bus_id: "TEST-0001", start: "08:28", finish: "09:00", go_back: 1 } ]
      rows = from_trips(trips, "SELECT (SELECT count(*) FROM layovers) AS n_layovers, negative FROM layover_exclusions")
      expect(rows).to eq([ { "n_layovers" => 0, "negative" => 1 } ])
    end

    it "下一趟是別的路線時不算，別的路線配對 1 組" do
      trips = [ { bus_id: "TEST-0001", start: "08:00", finish: "08:30" }, { bus_id: "TEST-0001", start: "08:40", finish: "09:10", route_id: 9100 } ]
      rows = from_trips(trips, "SELECT (SELECT count(*) FROM layovers) AS n_layovers, other_route FROM layover_exclusions")
      expect(rows).to eq([ { "n_layovers" => 0, "other_route" => 1 } ])
    end

    it "4、8、12、20、45 分鐘的 p10 是 5.6、p50 是 12.0、p90 是 35.0" do
      rows = from_trips(spaced_trips, "SELECT percentiles FROM layover_distribution WHERE go_back IS NULL")
      expect(rows).to eq([ { "percentiles" => [ 5.6, 12.0, 35.0 ] } ])
    end

    it "4、8、12、20、45 分鐘的分箱是 1、1、1、1、1、0，不到 15 分鐘的比例 60%" do
      rows = from_trips(spaced_trips, "SELECT bin_counts, short_share FROM layover_distribution WHERE go_back IS NULL")
      expect(rows).to eq([ { "bin_counts" => [ 1, 1, 1, 1, 1, 0 ], "short_share" => 0.6 } ])
    end

    it "剛好 15.0 分鐘落在 15 到 30 那一箱，不算不到 15 分鐘" do
      trips = [ { bus_id: "TEST-0001", start: "08:00", finish: "08:30" }, { bus_id: "TEST-0001", start: "08:45", finish: "09:15", go_back: 1 } ]
      rows = from_trips(trips, "SELECT bin_counts, short_share FROM layover_distribution WHERE go_back IS NULL")
      expect(rows).to eq([ { "bin_counts" => [ 0, 0, 0, 1, 0, 0 ], "short_share" => 0.0 } ])
    end

    it "沒有折返停留的方向仍有一列：筆數 0，百分位數與比例是空的" do
      trips = [ { bus_id: "TEST-0001", start: "08:00", finish: "08:30" }, { bus_id: "TEST-0001", start: "08:40", finish: "09:10", go_back: 1 } ]
      rows = from_trips(trips, "SELECT n_layovers, percentiles, short_share, bin_counts FROM layover_distribution WHERE go_back = 1")
      expect(rows).to eq([ { "n_layovers" => 0, "percentiles" => nil, "short_share" => nil, "bin_counts" => [ 0, 0, 0, 0, 0, 0 ] } ])
    end
  end
end
