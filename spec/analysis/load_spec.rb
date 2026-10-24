require "spec_helper"
require_relative "../support/duckdb"

RSpec.describe "analysis/10_load.sql" do
  def load_rows(query, **variables) = run_sql_stages(through: "10_load", query:, **variables)

  def input_files(feed, **variables)
    load_rows("SELECT regexp_extract(file, '[^/]+/[^/]+$') AS name FROM input_files WHERE feed = '#{feed}' ORDER BY name", **variables)
      .map { it["name"] }
  end

  let(:window) do
    [ "2026-10-18/22", "2026-10-18/23", "2026-10-19/00", *(6..23).map { format("2026-10-19/%02d", it) },
      "2026-10-20/00", "2026-10-20/01" ]
  end

  describe "讀檔視窗" do
    it "bus_event 讀前一天 22、23 時、當天全部與隔天 00、01 時，不讀 21 時與隔天 02 時" do
      expect(input_files("bus_event")).to eq(window.map { it == "2026-10-19/08" ? "#{it}.jsonl.gz" : "#{it}.jsonl" })
    end

    it "bus_seat_event 讀同一個視窗" do
      expect(input_files("bus_seat_event")).to eq(window.map { "#{it}.jsonl" })
    end

    it "前一天沒有檔時照常讀當天與隔天有的檔" do
      expect(input_files("bus_event", day: Date.new(2026, 10, 18))).to eq(
        %w[2026-10-18/21.jsonl 2026-10-18/22.jsonl 2026-10-18/23.jsonl 2026-10-19/00.jsonl]
      )
    end
  end

  describe "去重" do
    it "TEST-0001 07:59:58 跨兩個小時檔的重複只留先抓到的 07.jsonl 那筆" do
      rows = load_rows(<<~SQL)
        SELECT regexp_extract(source_file, '[^/]+$') AS file FROM bus_events
        WHERE bus_id = 'TEST-0001' AND data_time = TIMESTAMP '2026-10-19 07:59:58'
      SQL
      expect(rows).to eq([ { "file" => "07.jsonl" } ])
    end

    it "兩支 feed 分開計數，筆數是過濾路線之後、整個視窗內的" do
      expect(load_rows("SELECT feed, n_read, n_removed FROM load_counts ORDER BY feed")).to eq(
        [ { "feed" => "bus_event", "n_read" => 276, "n_removed" => 1 },
          { "feed" => "bus_seat_event", "n_read" => 130, "n_removed" => 2 } ]
      )
    end
  end

  describe "路線過濾" do
    it "只留路線 9001 的三條附屬路線，對照路線 9100 與 RouteID 0 都不進來" do
      rows = load_rows(<<~SQL)
        SELECT path_attribute_id FROM bus_events UNION SELECT path_attribute_id FROM seat_events ORDER BY 1
      SQL
      expect(rows.map { it["path_attribute_id"] }).to eq([ 9001, 9002, 9003 ])
    end
  end

  describe "別條路線的記錄" do
    it "other_route_events 是對照路線 9100 的 26 筆：TEST-0001 3 筆、TEST-0002 3 筆、TEST-0004 20 筆" do
      rows = load_rows("SELECT bus_id, path_attribute_id, count(*) AS n FROM other_route_events GROUP BY ALL ORDER BY bus_id")
      expect(rows.map(&:values)).to eq([ [ "TEST-0001", 9100, 3 ], [ "TEST-0002", 9100, 3 ], [ "TEST-0004", 9100, 20 ] ])
    end

    it "RouteID 0 的記錄不讀：TEST-0004 15:00 那筆不在裡面" do
      rows = load_rows(<<~SQL)
        SELECT count(*) AS n FROM other_route_events WHERE bus_id = 'TEST-0004' AND data_time = TIMESTAMP '2026-10-19 15:00:00'
      SQL
      expect(rows).to eq([ { "n" => 0 } ])
    end

    it "這條路線自己的附屬路線 9001、9002、9003 都不在裡面" do
      rows = load_rows("SELECT count(*) AS n FROM other_route_events WHERE path_attribute_id IN (9001, 9002, 9003)")
      expect(rows).to eq([ { "n" => 0 } ])
    end
  end

  describe "附屬路線對回路線與方向" do
    it "GetRoute.gz 裡附屬路線 9002 有兩列時，routes 仍是 9001、9002、9003 各一列" do
      expect(load_rows("SELECT path_attribute_id FROM routes ORDER BY 1").map { it["path_attribute_id"] }).to eq([ 9001, 9002, 9003 ])
    end

    it "附屬路線 9002 的事件對回路線 9001" do
      expect(load_rows("SELECT DISTINCT route_id FROM stop_events WHERE path_attribute_id = 9002")).to eq([ { "route_id" => 9001 } ])
    end

    it "站牌對到該方向的 seqNo：TEST-0001 08:54 在乙站是去程 seq 1，10:07 在丙站對面是返程 seq 7" do
      rows = load_rows(<<~SQL)
        SELECT go_back, seq FROM stop_events WHERE bus_id = 'TEST-0001'
          AND data_time IN (TIMESTAMP '2026-10-19 08:54:00', TIMESTAMP '2026-10-19 10:07:00') ORDER BY data_time
      SQL
      expect(rows).to eq([ { "go_back" => 0, "seq" => 1 }, { "go_back" => 1, "seq" => 7 } ])
    end

    it "站牌不在該方向的事件不進 stop_events，計入 unknown-stop" do
      rows = load_rows("SELECT bus_id, strftime(data_time, '%H:%M:%S') AS at, stop_id FROM unknown_stop_events")
      expect(rows).to eq([ { "bus_id" => "TEST-0003", "at" => "08:26:00", "stop_id" => 91007 } ])
    end

    it "去重後的到離站事件不是對到站序就是 unknown-stop，一筆不少" do
      rows = load_rows(<<~SQL)
        SELECT (SELECT count(*) FROM stop_events) + (SELECT count(*) FROM unknown_stop_events) = (SELECT count(*) FROM bus_events) AS all_accounted
      SQL
      expect(rows).to eq([ { "all_accounted" => true } ])
    end
  end

  describe "成員日 2026-10-23，9001 掛成員路線 9050" do
    def member_rows(query, member_route_ids: [ 9001, 9050 ])
      load_rows(query, member_route_ids:, day: Date.new(2026, 10, 23), static_day: Date.new(2026, 10, 23))
    end

    it "routes 是 9001 的三條附屬路線加 9050，各對回自己的路線 Id" do
      rows = member_rows("SELECT route_id, path_attribute_id FROM routes ORDER BY path_attribute_id")
      expect(rows.map(&:values)).to eq([ [ 9001, 9001 ], [ 9001, 9002 ], [ 9001, 9003 ], [ 9050, 9050 ] ])
    end

    it "stops 兩條路線各 10 站，帶站位：第三站 9001 是 81002、9050 是 85002" do
      rows = member_rows("SELECT route_id, count(*) AS n, min(stop_location_id) FILTER (WHERE seq = 2) AS third FROM stops GROUP BY route_id ORDER BY route_id")
      expect(rows.map(&:values)).to eq([ [ 9001, 10, 81002 ], [ 9050, 10, 85002 ] ])
    end

    it "RouteID 9050 的事件對回路線 9050，站序用 9050 自己的：己站 95002 是去程 seq 2" do
      rows = member_rows("SELECT DISTINCT route_id, go_back, seq FROM stop_events WHERE stop_id = 95002")
      expect(rows).to eq([ { "route_id" => 9050, "go_back" => 0, "seq" => 2 } ])
    end

    it "TEST-0005 的 9050 記錄不算別條路線：other_route_events 沒有它" do
      expect(member_rows("SELECT count(*) AS n FROM other_route_events WHERE bus_id = 'TEST-0005'")).to eq([ { "n" => 0 } ])
    end

    it "站序比對帶路線 Id：9050 跟 9050 自己的站序比，兩個方向都一樣，己站不在 9001 的站序上也沒關係" do
      rows = member_rows("SELECT route_id, path_attribute_id, directions, identical FROM sequence_check ORDER BY path_attribute_id")
      expect(rows.map(&:values)).to eq([ [ 9001, 9001, [ 0, 1 ], true ], [ 9001, 9002, [ 0 ], true ], [ 9001, 9003, [ 1 ], false ], [ 9050, 9050, [ 0, 1 ], true ] ])
    end

    it "清單裡的路線在 GetRoute.gz 沒有列時整個跑不下去，訊息寫出那個 Id" do
      expect { member_rows("SELECT 1", member_route_ids: [ 9001, 9060 ]) }.to raise_error(RuntimeError, /9060/)
    end

    it "2026-10-19 掛 9050：stops 多 9050 的 10 站，讀到的事件筆數不變" do
      rows = load_rows("SELECT (SELECT count(*) FROM stops) AS n_stops, (SELECT n_read FROM load_counts WHERE feed = 'bus_event') AS n_read", member_route_ids: [ 9001, 9050 ])
      expect(rows).to eq([ { "n_stops" => 20, "n_read" => 276 } ])
    end

    it "沒給 member_route_ids 時只有 route_id 那一條：stops 10 站、routes 三列" do
      rows = load_rows("SELECT (SELECT count(*) FROM stops) AS n_stops, (SELECT count(*) FROM routes) AS n_routes")
      expect(rows).to eq([ { "n_stops" => 10, "n_routes" => 3 } ])
    end
  end

  describe "附屬路線站序比對" do
    it "9001 跟整條路線比、9002 跟去程比都一樣，9003 跟返程比少一站" do
      rows = load_rows("SELECT path_attribute_id, directions, identical FROM sequence_check ORDER BY path_attribute_id")
      expect(rows).to eq([ { "path_attribute_id" => 9001, "directions" => [ 0, 1 ], "identical" => true },
                           { "path_attribute_id" => 9002, "directions" => [ 0 ], "identical" => true },
                           { "path_attribute_id" => 9003, "directions" => [ 1 ], "identical" => false } ])
    end

    it "站牌全都不在這條路線上的附屬路線，標成不一樣、沒有比對方向" do
      rows = load_rows(<<~SQL)
        UPDATE path_stops SET stop_id = stop_id + 1000000 WHERE path_attribute_id = 9003;
        SELECT directions, identical FROM sequence_check WHERE path_attribute_id = 9003
      SQL
      expect(rows).to eq([ { "directions" => [], "identical" => false } ])
    end
  end
end
