require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/30_layovers.sql 的班次串" do
  def chain_rows(query) = run_sql_stages(through: "30_layovers", query:)

  # Injected trips come with injected records on other routes, none by default.
  def from_trips(spans, query, records: [], **overrides)
    trips = spans.each_with_index.map { |(start, finish), index| { bus_id: "TEST-0001", start:, finish:, go_back: index % 2 } }
    overrides.each { |index, values| trips[index] = trips[index].merge(values) }
    chain_rows([ replace_trips_sql(trips), replace_other_route_events_sql(records), query ].join("\n"))
  end

  let(:report_query) { "SELECT strftime(start_time, '%H:%M') AS start, strftime(end_time, '%H:%M') AS finish, n_trips FROM chain_report" }
  let(:window_query) do
    "SELECT strftime(start_time, '%H:%M') AS start, window_minutes, credit_minutes, flagged FROM rest_windows ORDER BY start_time"
  end

  describe "fixture 的 2026-10-19" do
    it "只有一條班次串：06:00 到 11:30，5 趟" do
      expect(chain_rows(report_query)).to eq([ { "start" => "06:00", "finish" => "11:30", "n_trips" => 5 } ])
    end

    it "班次串 1 條，涉及車輛 1 台" do
      expect(chain_rows("SELECT n_chains, n_vehicles FROM chain_summary")).to eq([ { "n_chains" => 1, "n_vehicles" => 1 } ])
    end

    it "被標的視窗只有 TEST-0001 從 06:00 與 07:00 起的兩個，達 15 分鐘的停留都是 0" do
      rows = chain_rows("SELECT bus_id, strftime(start_time, '%H:%M') AS start, credit_minutes FROM rest_windows WHERE flagged ORDER BY start_time")
      expect(rows.map(&:values)).to eq([ [ "TEST-0001", "06:00", 0.0 ], [ "TEST-0001", "07:00", 0.0 ] ])
    end

    it "逐串明細有 bus_id，給卡用的班次串彙總沒有任何車牌欄位或車牌值" do
      columns = %w[chains chain_report].to_h { |view| [ view, chain_rows("DESCRIBE #{view}").map { it["column_name"] } ] }
      expect([ columns["chains"].include?("bus_id"), columns["chain_report"].grep(/bus/), chain_rows(report_query).to_s[/TEST-\d+/] ]).to eq([ true, [], nil ])
    end
  end

  describe "灌入的趟次" do
    it "06:00 到 08:30、08:40 到 11:10 兩趟只隔 10 分鐘：視窗 310 分鐘、額度 0，被標" do
      rows = from_trips([ %w[06:00 08:30], %w[08:40 11:10] ], window_query)
      expect(rows.first).to eq("start" => "06:00", "window_minutes" => 310.0, "credit_minutes" => 0.0, "flagged" => true)
    end

    it "三趟之間各停 20 分鐘：額度 40 分鐘，不被標" do
      rows = from_trips([ %w[06:00 07:30], %w[07:50 09:20], %w[09:40 11:10] ], window_query)
      expect(rows.first).to eq("start" => "06:00", "window_minutes" => 310.0, "credit_minutes" => 40.0, "flagged" => false)
    end

    it "從第 1 趟與第 2 趟起的視窗都被標而且共用第 2 趟：併成一串，涵蓋第 1 趟到第 3 趟" do
      rows = from_trips([ %w[06:00 08:00], %w[08:10 10:10], %w[10:20 12:20] ], report_query)
      expect(rows).to eq([ { "start" => "06:00", "finish" => "12:20", "n_trips" => 3 } ])
    end

    it "06:00 到 11:10 的三趟串成一串時，彙總列出起訖與 3 趟，沒有車牌" do
      rows = from_trips([ %w[06:00 07:40], %w[07:50 09:30], %w[09:35 11:10] ], report_query)
      expect(rows).to eq([ { "start" => "06:00", "finish" => "11:10", "n_trips" => 3 } ])
    end

    it "中間夾一趟不完整的，前後不接成同一個序列，沒有視窗" do
      rows = from_trips([ %w[06:00 08:00], %w[08:10 10:10], %w[10:20 12:20] ], "SELECT count(*) AS n FROM rest_windows",
                        1 => { completeness: "missing_start" })
      expect(rows).to eq([ { "n" => 0 } ])
    end

    it "額度只算視窗內的停留：第 2 趟之後那段 30 分鐘不算進從第 1 趟起的視窗" do
      rows = from_trips([ %w[06:00 08:00], %w[08:10 10:10], %w[10:40 12:40] ], window_query)
      expect(rows.first).to eq("start" => "06:00", "window_minutes" => 250.0, "credit_minutes" => 0.0, "flagged" => true)
    end

    it "單趟就超過 240 分鐘時，視窗只有這一趟、額度 0，被標" do
      rows = from_trips([ %w[06:00 10:30] ], report_query)
      expect(rows).to eq([ { "start" => "06:00", "finish" => "10:30", "n_trips" => 1 } ])
    end
  end

  describe "兩趟之間跑了別的路線" do
    let(:spans) { [ %w[10:20 11:08], %w[11:20 12:08], %w[17:10 17:58] ] }
    # Each run as the start times of its trips, each window with its flag, and the number of chains.
    let(:runs_query) do
      <<~SQL
        SELECT (SELECT list(starts ORDER BY first_start) FROM (
                  SELECT list(strftime(start_time, '%H:%M') ORDER BY start_time) AS starts, min(start_time) AS first_start
                  FROM rest_runs GROUP BY bus_id, run_no)) AS runs,
               (SELECT list({'start': strftime(start_time, '%H:%M'), 'flagged': flagged} ORDER BY start_time) FROM rest_windows) AS windows,
               (SELECT count(*) FROM chain_report) AS n_chains
      SQL
    end

    it "12:08 結束之後在 14:10 到 14:30 經過別條路線 3 個站：17:10 那趟開始新的序列，沒有視窗，也沒有班次串" do
      records = %w[14:10 14:20 14:30].each_with_index.map { |at, index| [ "TEST-0001", at, 92000 + index ] }
      expect(from_trips(spans, runs_query, records:).first).to eq("runs" => [ %w[10:20 11:20], %w[17:10] ], "windows" => nil, "n_chains" => 0)
    end

    it "對照：同樣三趟不灌記錄時在同一個序列，10:20 與 11:20 起的視窗有 302 分鐘的額度，都不被標" do
      expect(from_trips(spans, runs_query).first).to eq(
        "runs" => [ %w[10:20 11:20 17:10] ], "windows" => [ { "start" => "10:20", "flagged" => false }, { "start" => "11:20", "flagged" => false } ], "n_chains" => 0
      )
    end
  end
end
