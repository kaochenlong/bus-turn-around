require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/40_load_profile.sql" do
  def profile_rows(query) = run_sql_stages(through: "40_load_profile", query:)

  # Rows of `view` for the TEST-0001 trip that starts at `start` on 2026-10-19.
  def of_trip(view, start, columns)
    profile_rows(<<~SQL)
      SELECT #{columns} FROM #{view} v JOIN trips t USING (trip_id)
      WHERE t.bus_id = 'TEST-0001' AND t.start_time = TIMESTAMP '2026-10-19 #{start}' ORDER BY v.seq
    SQL
  end

  # Seat records of the TEST-0001 trip from 10:41 to 11:30: two departures at seq 1.
  let(:two_departures_at_one_stop) do
    <<~SQL
      DROP VIEW seat_stop_events;
      CREATE TABLE seat_stop_events AS SELECT * FROM (VALUES
        ('TEST-0001', 9001, 9001, 0, 1, 91001, 0, 5, TIMESTAMP '2026-10-19 10:53:30'),
        ('TEST-0001', 9001, 9001, 0, 1, 91001, 0, 6, TIMESTAMP '2026-10-19 10:54:00'))
        AS t(bus_id, route_id, path_attribute_id, go_back, seq, stop_id, car_on_stop, remaining_num, data_time);
    SQL
  end

  describe "接上趟次" do
    it "同一站有到站 11 與離站 14 時取離站的 14" do
      expect(of_trip("trip_stop_counts", "08:42:00", "v.seq, v.on_board").first(2).last).to eq("seq" => 1, "on_board" => 14)
    end

    it "10:41 起的去程接上四站的人數，趟末 11:30 之後 3 分鐘那筆沒接上" do
      rows = of_trip("trip_stop_counts", "10:41:00", "v.seq, v.on_board")
      expect(rows.map(&:values)).to eq([ [ 0, 0 ], [ 1, 5 ], [ 2, 10 ], [ 4, 7 ] ])
    end

    it "同一站有兩筆離站紀錄 5 與 6 時，取較晚的 6" do
      rows = profile_rows("#{two_departures_at_one_stop}SELECT seq, on_board FROM trip_stop_counts")
      expect(rows).to eq([ { "seq" => 1, "on_board" => 6 } ])
    end

    it "11:33 那筆不在任何一趟裡" do
      rows = profile_rows("SELECT count(*) AS n FROM trip_seat_records WHERE data_time = TIMESTAMP '2026-10-19 11:33:00'")
      expect(rows).to eq([ { "n" => 0 } ])
    end

    it "涵蓋率：27 趟中 20 趟有人數，126 個觀測到的站中 96 個有人數" do
      rows = profile_rows("SELECT trips_with_count, n_trips, stops_with_count, n_trip_stops FROM count_coverage")
      expect(rows).to eq([ { "trips_with_count" => 20, "n_trips" => 27, "stops_with_count" => 96, "n_trip_stops" => 126 } ])
    end

    it "涵蓋率的比例是相除的結果" do
      rows = profile_rows("SELECT round(trip_share, 4) AS trip_share, round(stop_share, 4) AS stop_share FROM count_coverage")
      expect(rows).to eq([ { "trip_share" => 0.7407, "stop_share" => 0.7619 } ])
    end
  end

  # SQL that swaps the mapped seat records for the given ones, each
  # [bus_id, go_back, seq, car_on_stop, on_board, "HH:MM"] on 2026-10-19.
  def seat_records_sql(records)
    values = records.map do |bus, go_back, seq, car_on_stop, count, at|
      "('#{bus}', 9001, 9001, #{go_back}, #{seq}, #{91000 + seq}, #{car_on_stop}, #{count}, TIMESTAMP '2026-10-19 #{at}:00')"
    end
    <<~SQL
      DROP VIEW seat_stop_events;
      CREATE TABLE seat_stop_events AS SELECT * FROM (VALUES #{values.join(', ')})
        AS t(bus_id, route_id, path_attribute_id, go_back, seq, stop_id, car_on_stop, remaining_num, data_time);
    SQL
  end

  def with_trips_and_seats(trips, records, query)
    profile_rows("#{replace_trips_sql(trips)}#{seat_records_sql(records)}#{query}")
  end

  describe "時段" do
    it "依趟次起點的時刻分段，邊界含起不含迄" do
      starts = %w[06:59 07:00 08:59 09:00 16:59 17:00 18:59 19:00]
      trips = starts.map { { bus_id: "TEST-0001", start: it, finish: it } }
      rows = profile_rows("#{replace_trips_sql(trips)}SELECT band FROM trip_bands ORDER BY trip_id")
      expect(rows.map { it["band"] }).to eq(%w[other morning_peak morning_peak daytime daytime evening_peak evening_peak other])
    end
  end

  describe "剖面表" do
    let(:morning_trips) do
      [ [ "TEST-0001", "07:00", "07:50" ], [ "TEST-0002", "07:10", "08:00" ], [ "TEST-0003", "08:00", "08:50" ] ]
        .map { |bus, start, finish| { bus_id: bus, start:, finish: } }
    end
    let(:counts_at_seq3) { [ [ "TEST-0001", 0, 3, 0, 10, "07:30" ], [ "TEST-0002", 0, 3, 0, 12, "07:40" ], [ "TEST-0003", 0, 3, 0, 20, "08:30" ] ] }

    it "早尖峰三趟去程在 seq 3 是 10、12、20：3 趟、中位數 12、p90 18.4，站名取 GetStop" do
      rows = with_trips_and_seats(morning_trips, counts_at_seq3, "SELECT go_back, band, seq, stop_name, n_trips, median, p90 FROM load_profile")
      expect(rows).to eq([ { "go_back" => 0, "band" => "morning_peak", "seq" => 3, "stop_name" => "丁站", "n_trips" => 3, "median" => 12.0, "p90" => 18.4 } ])
    end
  end

  describe "起末站歸零與異常" do
    let(:hourly_trips) { %w[06:00 07:00 08:00 09:00].map { { bus_id: "TEST-0001", start: it, finish: it.sub(":00", ":40") } } }
    let(:first_stop_report) do
      "SELECT n_trips, n_missing, share_zero, share_near_zero, max_count FROM reset_check WHERE terminal = 'first' AND go_back = 0"
    end

    # The count of one end of the TEST-0001 or TEST-0002 trip that starts at `start`.
    def reset_count(bus, start, terminal)
      profile_rows(<<~SQL).map { it["on_board"] }
        SELECT r.on_board FROM reset_counts r JOIN trips t USING (trip_id)
        WHERE t.bus_id = '#{bus}' AND t.start_time = TIMESTAMP '2026-10-19 #{start}' AND r.terminal = '#{terminal}'
      SQL
    end

    it "四趟完整趟次起站上客前是 0、0、2、9：4 趟有記錄、等於 0 的 50%、不超過 2 的 75%、最大 9" do
      records = [ 0, 0, 2, 9 ].zip(%w[05:50 06:50 07:50 08:50]).map { |count, at| [ "TEST-0001", 0, 0, 1, count, at ] }
      rows = with_trips_and_seats(hourly_trips, records, first_stop_report)
      expect(rows).to eq([ { "n_trips" => 4, "n_missing" => 0, "share_zero" => 0.5, "share_near_zero" => 0.75, "max_count" => 9 } ])
    end

    it "06:00 那趟起點前 60 分鐘整的 05:00 算，08:00 那趟起點前 61 分鐘的 06:59 不算：1 趟有記錄、1 趟沒有" do
      records = [ [ "TEST-0001", 0, 0, 1, 0, "05:00" ], [ "TEST-0001", 0, 0, 1, 0, "06:59" ] ]
      rows = with_trips_and_seats(hourly_trips.values_at(0, 2), records, first_stop_report)
      expect(rows.first.values_at("n_trips", "n_missing")).to eq([ 1, 1 ])
    end

    it "兩個方向分開報：去程起站甲站 1 趟是 0，返程起站戊站對面 1 趟是 5" do
      trips = [ { bus_id: "TEST-0001", start: "06:00", finish: "06:40" }, { bus_id: "TEST-0002", go_back: 1, start: "07:00", finish: "07:40" } ]
      records = [ [ "TEST-0001", 0, 0, 1, 0, "05:50" ], [ "TEST-0002", 1, 5, 1, 5, "06:50" ] ]
      rows = with_trips_and_seats(trips, records, "SELECT go_back, stop_name, n_trips, n_missing, share_zero FROM reset_check WHERE terminal = 'first' ORDER BY go_back")
      expect(rows.map(&:values)).to eq([ [ 0, "甲站", 1, 0, 1.0 ], [ 1, "戊站對面", 1, 0, 0.0 ] ])
    end

    it "起站上客前取起點前的到站記錄：08:42 那趟是 08:40 的 0，剖面的起站仍是 3" do
      expect([ reset_count("TEST-0001", "08:42:00", "first"), of_trip("trip_stop_counts", "08:42:00", "v.on_board").first ])
        .to eq([ [ 0 ], { "on_board" => 3 } ])
    end

    it "末站下客後取終點後的離站記錄：10:41 那趟是 11:33 的 0" do
      expect(reset_count("TEST-0001", "10:41:00", "last")).to eq([ 0 ])
    end

    it "起站的到站記錄在起點前 61 分鐘時不算：TEST-0002 17:10 那趟沒有起站上客前的人數" do
      expect(reset_count("TEST-0002", "17:10:00", "first")).to eq([])
    end

    it "fixture 的負值 1 筆、相鄰有人數的站跳動超過 30 的 1 次" do
      expect(profile_rows("SELECT negative_counts, jumps FROM count_anomalies")).to eq([ { "negative_counts" => 1, "jumps" => 1 } ])
    end
  end

  describe "成員日 2026-10-23，9001 掛成員路線 9050：沿線的數字以 9001 的站序為準" do
    def member_rows(query) = run_sql_stages(through: "40_load_profile", member_route_ids: [ 9001, 9050 ], day: Date.new(2026, 10, 23), static_day: Date.new(2026, 10, 23), query:)

    # Per direction and page route sequence number, the counts in trip order.
    let(:counts_by_page_seq) do
      "SELECT t.go_back, c.page_seq, list(c.on_board ORDER BY t.start_time) AS counts FROM trip_stop_counts c JOIN trips t USING (trip_id) " \
        "WHERE c.page_seq IS NOT NULL GROUP BY ALL ORDER BY ALL"
    end

    it "9050 兩趟的人數併到 9001 同站位的站：方向 0 的 seq 0、1、3、4 各兩趟，己站對不到所以 seq 2 沒有；方向 1 是 9001 那趟的 seq 5 到 9" do
      expect(member_rows(counts_by_page_seq).map(&:values)).to eq([ [ 0, 0, [ 3, 2 ] ], [ 0, 1, [ 5, 4 ] ], [ 0, 3, [ 6, 5 ] ], [ 0, 4, [ 2, 1 ] ],
                                                                     [ 1, 5, [ 4 ] ], [ 1, 6, [ 6 ] ], [ 1, 7, [ 5 ] ], [ 1, 8, [ 3 ] ], [ 1, 9, [ 1 ] ] ])
    end

    it "己站的 7 與 6 對不到 9001 的站位：page_seq 是空的，留著算淨上下車" do
      rows = member_rows("SELECT seq, on_board, page_seq FROM trip_stop_counts WHERE page_seq IS NULL ORDER BY on_board DESC")
      expect(rows.map(&:values)).to eq([ [ 2, 7, nil ], [ 2, 6, nil ] ])
    end

    it "剖面表用 9001 的站序與站名：方向 0 有甲、乙、丁、戊站，沒有丙站也沒有己站" do
      rows = member_rows("SELECT DISTINCT seq, stop_name FROM load_profile WHERE go_back = 0 ORDER BY seq")
      expect(rows.map(&:values)).to eq([ [ 0, "甲站" ], [ 1, "乙站" ], [ 3, "丁站" ], [ 4, "戊站" ] ])
    end

    it "剖面表依時段：07:00 那趟是早尖峰、09:00 那趟是日間，seq 0 各一趟，人數 3 與 2" do
      rows = member_rows("SELECT band, n_trips, median FROM load_profile WHERE go_back = 0 AND seq = 0 ORDER BY band")
      expect(rows.map(&:values)).to eq([ [ "daytime", 1, 2.0 ], [ "morning_peak", 1, 3.0 ] ])
    end

    it "淨上下車仍在 9050 自己的站序上算：第一趟己站 +2、丁站 -1，span 都是 1" do
      rows = member_rows(<<~SQL)
        SELECT n.seq, n.net_boarding, n.span FROM net_boarding n JOIN trips t USING (trip_id)
        WHERE t.bus_id = 'TEST-0005' AND t.start_time = TIMESTAMP '2026-10-23 07:00:00' AND n.seq IN (2, 3) ORDER BY n.seq
      SQL
      expect(rows.map(&:values)).to eq([ [ 2, 2, 1 ], [ 3, -1, 1 ] ])
    end

    it "歸零檢查的兩端用 9001 的站名，每個方向一列、沒有重複：方向 0 兩趟完整趟次都沒有記錄" do
      rows = member_rows("SELECT terminal, go_back, stop_name, n_trips, n_missing FROM reset_check ORDER BY go_back, terminal")
      expect(rows.map(&:values)).to eq([ [ "first", 0, "甲站", 0, 2 ], [ "last", 0, "戊站", 0, 2 ], [ "first", 1, "戊站對面", 0, 1 ], [ "last", 1, "甲站", 0, 1 ] ])
    end
  end

  describe "淨上下車" do
    it "seq 2 是 10、seq 3 沒有、seq 4 是 7 時，seq 4 的淨上下車 -3、span 2，標為跨站" do
      rows = of_trip("net_boarding", "10:41:00", "v.seq, v.net_boarding, v.span, v.crosses_missing_stops")
      expect(rows.map(&:values)).to eq([ [ 0, nil, nil, nil ], [ 1, 5, 1, false ], [ 2, 5, 1, false ], [ 4, -3, 2, true ] ])
    end
  end
end
