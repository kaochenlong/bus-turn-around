require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/20_trips.sql" do
  def trip_rows(query) = run_sql_stages(through: "20_trips", query:)

  # Replaces the fixture's stop events with the given ones (see
  # replace_stop_events_sql), then runs `query` against the trips built from them.
  def trips_from(events, query) = trip_rows("#{replace_stop_events_sql(events)}#{query}")

  # The trips of spec/fixtures/analysis/README.md: bus, go_back, start, end (day and time), completeness, sub-route.
  let(:readme_trips) do
    <<~TABLE.lines.map(&:split)
      TEST-0001 0 06:00:00 19T06:50:00 complete 9001
      TEST-0001 1 07:00:00 19T08:30:00 complete 9001
      TEST-0001 0 08:42:00 19T09:30:00 complete 9001
      TEST-0001 1 09:43:00 19T10:31:00 complete 9001
      TEST-0001 0 10:41:00 19T11:30:00 complete 9001
      TEST-0001 1 12:26:00 19T13:14:00 complete 9001
      TEST-0001 0 13:35:00 19T14:25:00 complete 9001
      TEST-0001 1 14:50:00 19T15:40:00 complete 9001
      TEST-0001 0 17:05:00 19T17:55:00 complete 9001
      TEST-0002 0 06:35:00 19T07:23:00 complete 9001
      TEST-0002 1 07:40:30 19T08:16:00 missing_start 9001
      TEST-0002 0 08:30:00 19T09:06:00 missing_end 9001
      TEST-0002 1 09:30:30 19T09:54:00 missing_both 9001
      TEST-0002 0 10:20:00 19T11:08:00 complete 9001
      TEST-0002 1 11:20:00 19T12:08:00 complete 9001
      TEST-0002 0 17:10:00 19T17:58:00 complete 9001
      TEST-0002 1 18:10:00 19T18:58:00 complete 9001
      TEST-0002 0 23:40:00 20T00:50:00 complete 9001
      TEST-0003 0 07:05:00 19T07:53:00 complete 9001
      TEST-0003 0 08:08:00 19T08:56:00 complete 9001
      TEST-0003 1 09:10:00 19T09:22:00 missing_end 9003
      TEST-0003 1 10:28:00 19T10:52:00 missing_start 9001
      TEST-0003 0 11:15:00 19T12:03:00 complete 9001
      TEST-0003 1 12:20:00 19T13:08:00 complete 9001
      TEST-0004 1 06:10:00 19T06:58:00 complete 9001
      TEST-0004 0 07:15:00 19T08:03:00 complete 9002
      TEST-0004 1 08:15:00 19T09:03:00 complete 9001
    TABLE
  end

  describe "fixture 的 2026-10-19" do
    it "趟次跟 fixture README 手算的 27 趟逐筆一致，含跨午夜那趟歸在當天" do
      rows = trip_rows(<<~SQL)
        SELECT bus_id, go_back, strftime(start_time, '%H:%M:%S') AS start, strftime(end_time, '%dT%H:%M:%S') AS finish,
               completeness, path_attribute_id FROM trips ORDER BY trip_id
      SQL
      expect(rows.map { it.values.map(&:to_s) }).to eq(readme_trips)
    end

    it "前一天發車與隔天發車的三趟切得出來，但起點不在當天所以不在 trips" do
      rows = trip_rows(<<~SQL)
        SELECT bus_id, strftime(start_time, '%Y-%m-%d %H:%M') AS start FROM segmented_trips
        WHERE CAST(start_time AS DATE) <> DATE '2026-10-19' ORDER BY start_time
      SQL
      expect(rows.map(&:values)).to eq([ %w[TEST-0003 2026-10-18\ 22:20], %w[TEST-0004 2026-10-18\ 23:30], %w[TEST-0004 2026-10-20\ 01:10] ])
    end

    it "起站只有到站、末站只有離站的那一趟，兩個旗標都是 true，其他趟都是 false" do
      rows = trip_rows(<<~SQL)
        SELECT bus_id, strftime(start_time, '%H:%M') AS start, start_from_arrival, end_from_departure FROM trips
        WHERE start_from_arrival OR end_from_departure
      SQL
      expect(rows).to eq([ { "bus_id" => "TEST-0002", "start" => "10:20", "start_from_arrival" => true, "end_from_departure" => true } ])
    end

    it "各附屬路線的趟數：9001 有 25 趟，9002、9003 各 1 趟" do
      rows = trip_rows("SELECT path_attribute_id, n_trips FROM path_trip_counts ORDER BY path_attribute_id")
      expect(rows.map(&:values)).to eq([ [ 9001, 25 ], [ 9002, 1 ], [ 9003, 1 ] ])
    end
  end

  describe "成員日 2026-10-23，9001 掛成員路線 9050" do
    def member_trips(query) = run_sql_stages(through: "20_trips", member_route_ids: [ 9001, 9050 ], day: Date.new(2026, 10, 23), static_day: Date.new(2026, 10, 23), query:)

    it "TEST-0005 三趟都完整：9050 去程 seq 0 到 4 兩趟，中間一趟 9001 返程 seq 5 到 9，各用自己的站序" do
      rows = member_trips("SELECT route_id, path_attribute_id, go_back, first_seq, last_seq, completeness, strftime(start_time, '%H:%M') AS start, " \
                          "strftime(end_time, '%H:%M') AS finish FROM trips ORDER BY trip_id")
      expect(rows.map(&:values)).to eq([ [ 9050, 9050, 0, 0, 4, "complete", "07:00", "07:50" ], [ 9001, 9001, 1, 5, 9, "complete", "08:00", "08:50" ],
                                         [ 9050, 9050, 0, 0, 4, "complete", "09:00", "09:50" ] ])
    end
  end

  describe "切趟" do
    [
      [ [ 0, 3, 1, "08:10:00" ], [ 0, 4, 1, "08:12:00" ], 1, "同方向站序遞增" ],
      [ [ 0, 4, 1, "08:12:00" ], [ 1, 5, 1, "08:20:00" ], 2, "方向改變" ],
      [ [ 0, 4, 1, "08:12:00" ], [ 0, 0, 1, "08:30:00" ], 2, "站序回頭" ],
      [ [ 0, 2, 1, "08:05:00" ], [ 0, 3, 1, "09:10:00" ], 2, "中斷 65 分鐘" ],
      [ [ 0, 2, 1, "08:05:00" ], [ 0, 2, 0, "08:06:00" ], 1, "同站先到後離" ]
    ].each do |previous, following, expected, label|
      it "#{label}：#{previous.last} 之後 #{following.last}，切成 #{expected} 趟" do
        rows = trips_from([ [ "TEST-0001", *previous ], [ "TEST-0001", *following ] ], "SELECT trip_id FROM trips")
        expect(rows.size).to eq(expected)
      end
    end
  end

  describe "完整性" do
    [ [ 0, 4, "complete" ], [ 1, 4, "missing_start" ], [ 0, 3, "missing_end" ], [ 1, 3, "missing_both" ] ].each do |first, last, expected|
      it "去程第一個觀測站 seq #{first}、最後一個 seq #{last} 是 #{expected}" do
        rows = trips_from([ [ "TEST-0001", 0, first, 0, "08:00:00" ], [ "TEST-0001", 0, last, 1, "08:30:00" ] ],
                          "SELECT completeness FROM trips")
        expect(rows).to eq([ { "completeness" => expected } ])
      end
    end
  end

  describe "起訖時刻" do
    it "起站有到站 06:52 與離站 07:00 時，起點是 07:00，start_from_arrival 是 false" do
      events = [ [ "TEST-0001", 0, 0, 1, "06:52:00" ], [ "TEST-0001", 0, 0, 0, "07:00:00" ], [ "TEST-0001", 0, 1, 1, "07:10:00" ] ]
      rows = trips_from(events, "SELECT strftime(start_time, '%H:%M:%S') AS start, start_from_arrival FROM trips")
      expect(rows).to eq([ { "start" => "07:00:00", "start_from_arrival" => false } ])
    end

    it "末站只有 08:31 的離站時，終點是 08:31，end_from_departure 是 true" do
      events = [ [ "TEST-0001", 0, 3, 0, "08:20:00" ], [ "TEST-0001", 0, 4, 0, "08:31:00" ] ]
      rows = trips_from(events, "SELECT strftime(end_time, '%H:%M:%S') AS finish, end_from_departure FROM trips")
      expect(rows).to eq([ { "finish" => "08:31:00", "end_from_departure" => true } ])
    end

    it "末站停著重報到站 14:09、14:19、14:32 時，終點取最早到的 14:09" do
      events = [ [ "TEST-0001", 0, 3, 0, "13:55:00" ], [ "TEST-0001", 0, 4, 1, "14:09:00" ],
                 [ "TEST-0001", 0, 4, 1, "14:19:00" ], [ "TEST-0001", 0, 4, 1, "14:32:00" ] ]
      expect(trips_from(events, "SELECT strftime(end_time, '%H:%M') AS finish FROM trips")).to eq([ { "finish" => "14:09" } ])
    end

    it "起站有兩筆離站 07:00、07:03 時，起點取最後離開的 07:03" do
      events = [ [ "TEST-0001", 0, 0, 0, "07:00:00" ], [ "TEST-0001", 0, 0, 0, "07:03:00" ], [ "TEST-0001", 0, 1, 1, "07:15:00" ] ]
      expect(trips_from(events, "SELECT strftime(start_time, '%H:%M') AS start FROM trips")).to eq([ { "start" => "07:03" } ])
    end
  end

  describe "附屬路線" do
    it "一趟 30 筆 9001、2 筆 9002 時記 9001，9001 的趟數加一" do
      events = (0...32).map { [ "TEST-0001", 0, [ it / 7, 4 ].min, 1, format("08:%02d:00", it), it < 2 ? 9002 : 9001 ] }
      rows = trips_from(events, "SELECT path_attribute_id, n_trips FROM path_trip_counts WHERE n_trips > 0")
      expect(rows).to eq([ { "path_attribute_id" => 9001, "n_trips" => 1 } ])
    end
  end
end
