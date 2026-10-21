require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/50_quality.sql 與 analysis/60_export.sql" do
  def quality_rows(query) = run_sql_stages(through: "50_quality", query:)

  # Runs every stage with the given inspection directory; the output is the card JSON row.
  def export_to(dir) = run_sql_stages(through: "60_export", query: "", inspect_dir: dir)

  # Seven trips that end on a DutyStatus 2 event, then one trip with three
  # DutyStatus 2 events before a final DutyStatus 1 event.
  let(:duty_events) do
    ended = (0..6).flat_map do |index|
      go_back = index % 2
      first, last = go_back.zero? ? [ 0, 4 ] : [ 5, 9 ]
      start = format("%02d:%02d:00", 6 + (index * 30 / 60), index * 30 % 60)
      finish = format("%02d:%02d:00", 6 + ((index * 30) + 20) / 60, ((index * 30) + 20) % 60)
      [ [ "TEST-0001", go_back, first, 0, start ], [ "TEST-0001", go_back, last, 1, finish, 9001, 2 ] ]
    end
    ended + [ [ "TEST-0001", 1, 5, 0, "09:30:00", 9001, 2 ], [ "TEST-0001", 1, 6, 1, "09:35:00", 9001, 2 ],
              [ "TEST-0001", 1, 7, 1, "09:40:00", 9001, 2 ], [ "TEST-0001", 1, 9, 1, "09:50:00" ] ]
  end

  let(:expected_headers) do
    { "trips" => "bus_id,route_id,path_attribute_id,go_back,start_time,end_time,first_seq,last_seq,n_events," \
                 "n_stops_observed,completeness,start_from_arrival,end_from_departure",
      "layovers" => "bus_id,route_id,go_back,end_time,next_start_time,minutes",
      "chains" => "chain_id,bus_id,start_time,end_time,n_trips",
      "profile" => "go_back,band,seq,stop_name,n_trips,median,p90",
      "quality" => "metric,subject,value" }
  end

  describe "fixture 的資料品質數字" do
    it "趟次 27 趟：complete 22、missing_start 2、missing_end 2、missing_both 1" do
      rows = quality_rows("SELECT completeness, n_trips FROM completeness_counts")
      expect(rows.to_h { it.values_at("completeness", "n_trips") }).to eq(
        "complete" => 22, "missing_start" => 2, "missing_end" => 2, "missing_both" => 1
      )
    end

    it "各附屬路線的趟數比例：9001 是 25/27，9002 與 9003 各 1/27" do
      rows = quality_rows("SELECT path_attribute_id, n_trips, round(share, 4) AS share FROM path_trip_shares ORDER BY path_attribute_id")
      expect(rows.map(&:values)).to eq([ [ 9001, 25, 0.9259 ], [ 9002, 1, 0.037 ], [ 9003, 1, 0.037 ] ])
    end

    it "22 趟完整趟次都觀測到全部 5 站，110 站中漏 0 站" do
      expect(quality_rows("SELECT missing_stops, direction_stops, rate FROM missing_stop_rate")).to eq(
        [ { "missing_stops" => 0, "direction_stops" => 110, "rate" => 0.0 } ]
      )
    end

    it "當天趟次裡的 DutyStatus：1 有 243 筆、2 有 4 筆" do
      rows = quality_rows("SELECT duty_status, n_events FROM duty_status_counts ORDER BY duty_status")
      expect(rows.map(&:values)).to eq([ [ 1, 243 ], [ 2, 4 ] ])
    end

    it "最後一筆是 DutyStatus 2 的趟次 27 趟中 3 趟，DutyStatus 2 的 4 筆中 3 筆在趟末" do
      rows = quality_rows("SELECT trips_ending_duty_2, n_trips, final_duty_2_events, duty_2_events FROM duty_status_trip_ends")
      expect(rows).to eq([ { "trips_ending_duty_2" => 3, "n_trips" => 27, "final_duty_2_events" => 3, "duty_2_events" => 4 } ])
    end

    it "長表收齊每支 feed 讀到與去掉的筆數，以及 unknown-stop" do
      rows = quality_rows("SELECT metric, subject, value FROM quality WHERE metric IN ('records_read', 'duplicates_removed', 'unknown_stop_events') ORDER BY metric, subject")
      expect(rows.map(&:values)).to eq([ %w[duplicates_removed bus_event 1], %w[duplicates_removed bus_seat_event 2],
                                         %w[records_read bus_event 276], %w[records_read bus_seat_event 130], [ "unknown_stop_events", "", "1" ] ])
    end

    it "末站在終點後有離站事件：去程末站戊站 13 趟完整趟次中 11 趟，返程末站甲站 9 趟中 9 趟" do
      rows = quality_rows("SELECT go_back, stop_name, complete_trips, with_departure FROM last_stop_departures ORDER BY go_back")
      expect(rows.map(&:values)).to eq([ [ 0, "戊站", 13, 11 ], [ 1, "甲站", 9, 9 ] ])
    end

    it "長表收齊每個方向的完整趟次與末站有離站事件的趟數" do
      rows = quality_rows("SELECT metric, subject, value FROM quality WHERE metric IN ('complete_trips', 'last_stop_departures') ORDER BY metric, subject")
      expect(rows.map(&:values)).to eq([ %w[complete_trips 0 13], %w[complete_trips 1 9], %w[last_stop_departures 0 11], %w[last_stop_departures 1 9] ])
    end

    it "長表收齊各附屬路線是那台車當天第一趟與最後一趟的趟數" do
      rows = quality_rows("SELECT metric, subject, value FROM quality WHERE metric IN ('first_trips', 'last_trips') ORDER BY metric, subject")
      expect(rows.map(&:values)).to eq([ %w[first_trips 9001 4], %w[first_trips 9002 0], %w[first_trips 9003 0],
                                         %w[last_trips 9001 4], %w[last_trips 9002 0], %w[last_trips 9003 0] ])
    end

    it "長表收齊各附屬路線的站序比對結果與比對的方向" do
      rows = quality_rows("SELECT subject, value FROM quality WHERE metric = 'sequence_check' ORDER BY subject")
      expect(rows.map(&:values)).to eq([ [ "9001", "identical, directions 0+1" ], [ "9002", "identical, directions 0" ], [ "9003", "not identical, directions 1" ] ])
    end
  end

  describe "灌入的資料" do
    it "5 站方向兩趟完整趟次觀測到 5 與 4 站時，漏站率 10%" do
      trips = [ { bus_id: "TEST-0001", start: "08:00", finish: "08:40" },
                { bus_id: "TEST-0002", start: "09:00", finish: "09:40", n_stops_observed: 4 } ]
      rows = quality_rows("#{replace_trips_sql(trips)}SELECT missing_stops, direction_stops, rate FROM missing_stop_rate")
      expect(rows).to eq([ { "missing_stops" => 1, "direction_stops" => 10, "rate" => 0.1 } ])
    end

    it "A 車依序 9002、9001、9001 三趟、B 車一趟 9003 時：9002 第一趟 1 最後 0，9001 是 0 與 1，9003 是 1 與 1" do
      trips = [ [ "TEST-0001", 9002, "06:00" ], [ "TEST-0001", 9001, "08:00" ], [ "TEST-0001", 9001, "10:00" ], [ "TEST-0002", 9003, "07:00" ] ]
        .map { |bus, path, start| { bus_id: bus, path_attribute_id: path, start:, finish: start.sub(":00", ":40") } }
      rows = quality_rows("#{replace_trips_sql(trips)}SELECT path_attribute_id, n_first, n_last FROM vehicle_day_ends ORDER BY 1")
      expect(rows.map(&:values)).to eq([ [ 9001, 0, 1 ], [ 9002, 1, 0 ], [ 9003, 1, 1 ] ])
    end

    it "返程兩趟完整趟次，一趟終點後 5 分鐘有末站離站、一趟只在 2 分鐘後又到站一次：2 趟中 1 趟有離站" do
      events = [ [ "TEST-0001", 1, 5, 0, "09:10:00" ], [ "TEST-0001", 1, 9, 1, "10:00:00" ], [ "TEST-0001", 1, 9, 0, "10:05:00" ],
                 [ "TEST-0001", 1, 5, 0, "11:10:00" ], [ "TEST-0001", 1, 9, 1, "12:00:00" ], [ "TEST-0001", 1, 9, 1, "12:02:00" ] ]
      rows = quality_rows("#{replace_stop_events_sql(events)}SELECT complete_trips, with_departure FROM last_stop_departures WHERE go_back = 1")
      expect(rows).to eq([ { "complete_trips" => 2, "with_departure" => 1 } ])
    end

    it "10 筆 DutyStatus 2 中 7 筆是該趟最後一筆時，比例 70%" do
      rows = quality_rows("#{replace_stop_events_sql(duty_events)}SELECT final_duty_2_events, duty_2_events, event_share FROM duty_status_trip_ends")
      expect(rows).to eq([ { "final_duty_2_events" => 7, "duty_2_events" => 10, "event_share" => 0.7 } ])
    end
  end

  describe "匯出" do
    it "五個 CSV 都寫到檢查目錄，欄位名照固定順序" do
      Dir.mktmpdir do |dir|
        export_to(dir)
        expect(expected_headers.keys.to_h { [ it, File.foreach(File.join(dir, "#{it}.csv")).first.chomp ] }).to eq(expected_headers)
      end
    end

    it "trips.csv 有 27 列，依車牌與起點排序，第一列是 TEST-0001 06:00 那趟" do
      Dir.mktmpdir do |dir|
        export_to(dir)
        lines = File.readlines(File.join(dir, "trips.csv"))
        expect([ lines.size, lines[1][/\A[^,]+,[^,]+,[^,]+,[^,]+,[^,]+/] ]).to eq([ 28, "TEST-0001,9001,9001,0,2026-10-19 06:00:00" ])
      end
    end

    it "最後輸出一列給卡用的 JSON，含路線、日期與各節的數字" do
      card = Dir.mktmpdir { export_to(it) }.first.fetch("card")
      picked = [ card.dig("route", "name"), card["day"], card.dig("quality", "unknown_stop_events"),
                 card.dig("trips", "total"), card.dig("chains", "summary", "n_chains"), card.dig("profile", "anomalies", "jumps") ]
      expect(picked).to eq([ "測試幹線", "2026-10-19", 1, 27, 1, 1 ])
    end

    it "給卡用的 JSON 在每條附屬路線帶當天第一趟與最後一趟的趟數" do
      card = Dir.mktmpdir { export_to(it) }.first.fetch("card")
      ends = card.dig("quality", "path_trips").map { it.values_at("path_attribute_id", "n_first", "n_last") }
      expect(ends).to eq([ [ 9001, 4, 4 ], [ 9002, 0, 0 ], [ 9003, 0, 0 ] ])
    end
  end
end
