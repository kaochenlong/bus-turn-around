require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/30_layovers.sql" do
  def layover_rows(query) = run_sql_stages(through: "30_layovers", query:)

  # Injected trips come with injected records on other routes, none by default.
  def from_trips(trips, query, records = []) = layover_rows([ replace_trips_sql(trips), replace_other_route_events_sql(records), query ].join("\n"))

  # Six complete trips of one vehicle with layovers of 4, 8, 12, 20 and 45 minutes.
  let(:spaced_trips) do
    [ %w[06:00 06:30], %w[06:34 07:00], %w[07:08 07:30], %w[07:42 08:00], %w[08:20 08:30], %w[09:15 09:45] ]
      .each_with_index.map { |(start, finish), index| { bus_id: "TEST-0001", start:, finish:, go_back: index % 2 } }
  end

  describe "fixture 的 2026-10-19" do
    it "折返停留跟 fixture README 手算的 18 筆一致，每台車依序" do
      rows = layover_rows("SELECT bus_id, list(minutes ORDER BY end_time) AS minutes FROM layovers GROUP BY bus_id ORDER BY bus_id")
      expect(rows.to_h { [ it["bus_id"], it["minutes"] ] }).to eq(
        "TEST-0001" => [ 10.0, 12.0, 13.0, 10.0, 56.0, 21.0, 25.0, 85.0 ],
        "TEST-0002" => [ 14.0, 12.0, 12.0, 282.0 ], "TEST-0003" => [ 15.0, 14.0, 23.0, 17.0 ], "TEST-0004" => [ 17.0, 12.0 ]
      )
    end

    it "TEST-0002 12:08 結束、17:10 出發的那一組，中間在對照路線經過 3 個站：跑了別的路線，不算折返停留" do
      rows = layover_rows("SELECT ran_other_route, category FROM layover_pairs WHERE bus_id = 'TEST-0002' AND end_time = TIMESTAMP '2026-10-19 12:08:00'")
      expect(rows).to eq([ { "ran_other_route" => true, "category" => "other_route" } ])
    end

    it "TEST-0001 15:40 結束、17:05 出發的那一組，中間在對照路線只經過 2 個站：沒有跑別的路線，仍是 85.0 分鐘" do
      rows = layover_rows("SELECT ran_other_route, category, minutes FROM layover_pairs WHERE bus_id = 'TEST-0001' AND end_time = TIMESTAMP '2026-10-19 15:40:00'")
      expect(rows).to eq([ { "ran_other_route" => false, "category" => "layover", "minutes" => 85.0 } ])
    end

    it "08:30 結束的完整趟次與 08:42 開始的下一趟，折返停留 12.0 分鐘" do
      rows = layover_rows("SELECT minutes FROM layovers WHERE bus_id = 'TEST-0001' AND end_time = TIMESTAMP '2026-10-19 08:30:00'")
      expect(rows).to eq([ { "minutes" => 12.0 } ])
    end

    it "量不到的配對：本趟沒有到末站 3 組、下一趟不是從起站出發 1 組、兩趟之間跑了別的路線 1 組，差值為負是 0" do
      expect(layover_rows("SELECT no_last_stop, no_first_stop, other_route, negative FROM layover_exclusions")).to eq(
        [ { "no_last_stop" => 3, "no_first_stop" => 1, "other_route" => 1, "negative" => 0 } ]
      )
    end

    it "TEST-0004 對照路線的記錄都在當天最後一趟之後：兩組配對都沒有跑別的路線，折返停留仍是 17.0、12.0" do
      rows = layover_rows("SELECT ran_other_route, category, minutes FROM layover_pairs WHERE bus_id = 'TEST-0004' ORDER BY end_time")
      expect(rows.map(&:values)).to eq([ [ false, "layover", 17.0 ], [ false, "layover", 12.0 ] ])
    end

    it "每台車當天最後一趟沒有折返停留" do
      rows = layover_rows(<<~SQL)
        SELECT count(*) AS n FROM layovers l JOIN trips t USING (trip_id)
        WHERE t.start_time = (SELECT max(start_time) FROM trips WHERE bus_id = t.bus_id)
      SQL
      expect(rows).to eq([ { "n" => 0 } ])
    end

    it "按結束那趟的方向分列：去程 10 筆、中位數 13.5，返程 8 筆、中位數 19.0" do
      rows = layover_rows(<<~SQL)
        SELECT go_back, n_layovers, percentiles[2] AS p50 FROM layover_distribution WHERE go_back IS NOT NULL ORDER BY go_back
      SQL
      expect(rows).to eq([ { "go_back" => 0, "n_layovers" => 10, "p50" => 13.5 }, { "go_back" => 1, "n_layovers" => 8, "p50" => 19.0 } ])
    end
  end

  describe "灌入的趟次" do
    # Two consecutive trips of one vehicle, 08:00–08:16 then 08:30–09:00, with
    # the given completeness; returns the layovers and the exclusion counts.
    def pair(current, following)
      trips = [ { bus_id: "TEST-0001", start: "08:00", finish: "08:16", completeness: current },
                { bus_id: "TEST-0001", start: "08:30", finish: "09:00", go_back: 1, completeness: following } ]
      from_trips(trips, <<~SQL).first
        SELECT (SELECT list(minutes) FROM layovers) AS minutes, no_last_stop, no_first_stop FROM layover_exclusions
      SQL
    end

    it "漏起站的那趟 08:16 到末站、下一趟漏末站但 08:30 從起站出發，折返停留 14.0 分鐘" do
      expect(pair("missing_start", "missing_end")).to eq("minutes" => [ 14.0 ], "no_last_stop" => 0, "no_first_stop" => 0)
    end

    it "本趟漏末站時不算，算在本趟沒有到末站" do
      expect(pair("missing_end", "complete")).to eq("minutes" => nil, "no_last_stop" => 1, "no_first_stop" => 0)
    end

    it "下一趟漏起站時不算，算在下一趟不是從起站出發" do
      expect(pair("complete", "missing_start")).to eq("minutes" => nil, "no_last_stop" => 0, "no_first_stop" => 1)
    end

    it "兩端都缺時只算在本趟沒有到末站" do
      expect(pair("missing_end", "missing_start")).to eq("minutes" => nil, "no_last_stop" => 1, "no_first_stop" => 0)
    end

    it "完整趟次 08:30 結束、下一趟 08:28 開始時不算，負值配對 1 組" do
      trips = [ { bus_id: "TEST-0001", start: "08:00", finish: "08:30" }, { bus_id: "TEST-0001", start: "08:28", finish: "09:00", go_back: 1 } ]
      rows = from_trips(trips, "SELECT (SELECT count(*) FROM layovers) AS n_layovers, negative FROM layover_exclusions")
      expect(rows).to eq([ { "n_layovers" => 0, "negative" => 1 } ])
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

  describe "兩趟之間跑了別的路線" do
    # TEST-0001's trip 08:00–08:30 with the given completeness, then its next
    # complete trip from `next_start`, with the given records on other routes;
    # returns the layovers and the exclusion counts.
    def across(records, next_start: "09:30", current: "complete")
      trips = [ { bus_id: "TEST-0001", start: "08:00", finish: "08:30", completeness: current },
                { bus_id: "TEST-0001", start: next_start, finish: "10:30", go_back: 1 } ]
      from_trips(trips, <<~SQL, records).first
        SELECT (SELECT list(minutes) FROM layovers) AS minutes, no_last_stop, other_route, negative FROM layover_exclusions
      SQL
    end

    # Records at `count` distinct stops of route 9100, one a minute from 08:32.
    def distinct_stops(count, bus: "TEST-0001") = Array.new(count) { [ bus, format("08:%02d", 32 + it), 92000 + it ] }

    it "08:30 結束、09:30 出發，中間在路線 9100 經過 3 個站：不算折返停留，跑了別的路線 1 組" do
      expect(across(distinct_stops(3))).to eq("minutes" => nil, "no_last_stop" => 0, "other_route" => 1, "negative" => 0)
    end

    it "08:30 結束、08:42 出發，中間在路線 9100 同一個站有 3 筆：只經過 1 個站，折返停留 12.0 分鐘" do
      records = %w[08:32 08:35 08:38].map { [ "TEST-0001", it, 92000 ] }
      expect(across(records, next_start: "08:42")).to eq("minutes" => [ 12.0 ], "no_last_stop" => 0, "other_route" => 0, "negative" => 0)
    end

    [ [ 0, "仍算折返停留", [ [ 12.0 ], 0 ] ], [ 2, "仍算折返停留", [ [ 12.0 ], 0 ] ], [ 3, "算跑了別的路線", [ nil, 1 ] ] ].each do |count, outcome, expected|
      it "門檻邊界：兩趟之間經過別條路線 #{count} 個站，#{outcome}" do
        expect(across(distinct_stops(count), next_start: "08:42").values_at("minutes", "other_route")).to eq(expected)
      end
    end

    it "本趟漏末站、中間在路線 9100 經過 3 個站：只算在本趟沒有到末站" do
      expect(across(distinct_stops(3), current: "missing_end")).to eq("minutes" => nil, "no_last_stop" => 1, "other_route" => 0, "negative" => 0)
    end

    it "剛好在本趟終點與下一趟起點那一刻的記錄不算在兩趟之間：中間只剩 1 個站，折返停留 12.0 分鐘" do
      records = [ [ "TEST-0001", "08:30", 92000 ], [ "TEST-0001", "08:36", 92001 ], [ "TEST-0001", "08:42", 92002 ] ]
      expect(across(records, next_start: "08:42")["minutes"]).to eq([ 12.0 ])
    end

    it "別台車在這段時間經過 3 個站不影響這台車：折返停留 12.0 分鐘" do
      expect(across(distinct_stops(3, bus: "TEST-0002"), next_start: "08:42")["minutes"]).to eq([ 12.0 ])
    end

    it "差值為負的配對沒有「兩趟之間」：記錄落在重疊的那兩分鐘裡，仍算差值為負" do
      records = %w[08:28:30 08:29:00 08:29:30].each_with_index.map { |at, index| [ "TEST-0001", at, 92000 + index ] }
      expect(across(records, next_start: "08:28")).to eq("minutes" => nil, "no_last_stop" => 0, "other_route" => 0, "negative" => 1)
    end
  end
end
