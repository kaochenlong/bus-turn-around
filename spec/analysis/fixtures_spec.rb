require "spec_helper"
require "zlib"
require_relative "../support/duckdb"

RSpec.describe "spec/fixtures/analysis" do
  def static_file(name)
    path = File.join(DuckdbHelpers::FIXTURE_DATA, "static/2026-10-19", name)
    Zlib::GzipReader.open(path) { JSON.parse(it.read) }
  end

  def static_rows(name) = static_file(name).fetch("BusInfo")

  # Every record of one feed, with the hour file it came from as "file".
  def feed_records(feed)
    base = File.join(DuckdbHelpers::FIXTURE_DATA, feed)
    Dir[File.join(base, "*", "*.jsonl{,.gz}")].sort.flat_map do |path|
      lines = path.end_with?(".gz") ? Zlib::GzipReader.open(path, &:readlines) : File.readlines(path)
      lines.map { JSON.parse(it).merge("file" => path.delete_prefix("#{base}/")) }
    end
  end

  def feed_files(feed)
    base = File.join(DuckdbHelpers::FIXTURE_DATA, feed)
    Dir[File.join(base, "*", "*")].map { it.delete_prefix("#{base}/") }.sort
  end

  # Records of one vehicle whose DataTime is within [from, to]; a bare time means 2026-10-19.
  def slice(bus, from, to)
    from, to = [ from, to ].map { it.include?(" ") ? it : "2026-10-19 #{it}" }
    records.select { it["BusID"] == bus && it["DataTime"].between?(from, to) }.sort_by { it.values_at("DataTime", "file") }
  end

  def stop_ids(bus, from, to) = slice(bus, from, to).map { it["StopID"] }.uniq

  let(:window_hours) do
    [ "2026-10-18/21", "2026-10-18/22", "2026-10-18/23", "2026-10-19/00",
      *(6..23).map { format("2026-10-19/%02d", it) }, "2026-10-20/00", "2026-10-20/01", "2026-10-20/02" ]
  end

  describe "static/2026-10-19" do
    let(:stops) { static_rows("GetStop.gz").select { it["routeId"] == 9001 }.sort_by { it["seqNo"] } }
    let(:back_stop_ids) { stops.select { it["goBack"] == "1" }.map { it["Id"] } }
    let(:paths) do
      static_rows("GetPathDetail.gz").group_by { it["pathAttributeId"] }
                                     .transform_values { |rows| rows.sort_by { it["sequenceNo"] } }
    end

    it "三支檔跟真資料一樣，是 EssentialInfo 與 BusInfo 包起來的單一物件" do
      keys = %w[GetRoute.gz GetStop.gz GetPathDetail.gz].map { static_file(it).keys }
      expect(keys).to all(eq(%w[EssentialInfo BusInfo]))
    end

    it "路線 9001 有附屬路線 9001、9002、9003，另有一條對照路線 9100" do
      pairs = static_rows("GetRoute.gz").map { [ it["Id"], it["pathAttributeId"] ] }
      expect(pairs).to contain_exactly([ 9001, 9001 ], [ 9001, 9002 ], [ 9001, 9003 ], [ 9100, 9100 ])
    end

    it "路線 9001 每方向 5 站，seqNo 0 到 9 連號" do
      expect(stops.map { [ it["goBack"], it["seqNo"] ] }).to eq((0..4).map { [ "0", it ] } + (5..9).map { [ "1", it ] })
    end

    it "路線 9001 兩端站名相同但站牌 Id 不同" do
      ends = [ stops.first, stops.last ]
      expect(ends.map { it["nameZh"] }.uniq.size => ends.map { it["Id"] }.uniq.size).to eq(1 => 2)
    end

    it "附屬路線 9001 的站序等於去程接返程" do
      expect(paths[9001].map { it["stopId"] }).to eq(stops.map { it["Id"] })
    end

    it "附屬路線 9002 的站序等於去程" do
      expect(paths[9002].map { it["stopId"] }).to eq(stops.select { it["goBack"] == "0" }.map { it["Id"] })
    end

    it "附屬路線 9003 的站序是返程少掉一站" do
      ids = paths[9003].map { it["stopId"] }
      expect([ ids.size, (ids - back_stop_ids).size, (back_stop_ids - ids).size ]).to eq([ 4, 0, 1 ])
    end

    it "GetPathDetail 的 sequenceNo 跟真資料一樣，每條附屬路線各自從 0 起算" do
      expect(paths.transform_values { |rows| rows.map { it["sequenceNo"] } }).to eq(
        9001 => (0..9).to_a, 9002 => (0..4).to_a, 9003 => (0..3).to_a, 9100 => (0..3).to_a
      )
    end

    it "路線 9001 的十個站牌座標兩兩不同，量得出到捷運出入口的距離" do
      expect(stops.map { it.values_at("latitude", "longitude") }.uniq.size).to eq(10)
    end
  end

  describe "external/taipei-mrt-exits" do
    it "2026-10-19 的快照有表頭與兩個出入口" do
      lines = File.readlines(File.join(DuckdbHelpers::FIXTURE_DATA, "external/taipei-mrt-exits/2026-10-19.csv"), chomp: true)
      expect([ lines.first, lines.size - 1 ]).to eq([ "項次,出入口名稱,出入口編號,經度,緯度,是否為無障礙用", 2 ])
    end
  end

  describe "external/office-calendar" do
    it "2026 的快照有表頭與 365 天，其中假日 120 天" do
      lines = File.readlines(File.join(DuckdbHelpers::FIXTURE_DATA, "external/office-calendar/2026/2026-10-19.csv"), chomp: true)
      expect([ lines.first, lines.size - 1, lines.count { it.split(",")[2] == "2" } ]).to eq([ "西元日期,星期,是否放假,備註", 365, 120 ])
    end
  end

  describe "bus_event" do
    let(:records) { feed_records("bus_event") }

    def found(bus, data_time, *fields) = slice(bus, data_time, data_time).map { it.values_at(*fields) }

    it "讀檔視窗內的小時檔與視窗外的兩個檔都在，08 時是 gz" do
      expected = window_hours.map { it.end_with?("19/08") ? "#{it}.jsonl.gz" : "#{it}.jsonl" }
      expect(feed_files("bus_event")).to eq(expected)
    end

    it "車牌只用 TEST-0001 到 TEST-0004" do
      expect(records.map { it["BusID"] }.uniq.sort).to eq(%w[TEST-0001 TEST-0002 TEST-0003 TEST-0004])
    end

    it "RouteID 有路線 9001 的三條附屬路線、對照路線 9100 與非營運的 0" do
      expect(records.map { it["RouteID"] }.uniq.sort).to eq(%w[0 9001 9002 9003 9100])
    end

    it "完整趟：TEST-0001 06:00 從起站離站，06:50 到末站" do
      ends = slice("TEST-0001", "06:00:00", "06:50:00").values_at(0, -1)
      expect(ends.map { it.values_at("StopID", "CarOnStop") }).to eq([ %w[91000 0], %w[91004 1] ])
    end

    it "漏起站：TEST-0002 07:40 起的返程沒有起站" do
      expect(stop_ids("TEST-0002", "07:40:00", "08:17:00")).to eq(%w[91006 91007 91008 91009])
    end

    it "漏末站：TEST-0002 08:25 起的去程沒有末站" do
      expect(stop_ids("TEST-0002", "08:25:00", "09:07:00")).to eq(%w[91000 91001 91002 91003])
    end

    it "兩端都漏：TEST-0002 09:30 起的返程只有中間三站" do
      expect(stop_ids("TEST-0002", "09:30:00", "09:55:00")).to eq(%w[91006 91007 91008])
    end

    it "起站只有到站、末站只有離站：TEST-0002 10:20 到站、11:08 離站" do
      ends = slice("TEST-0002", "10:20:00", "11:08:00").values_at(0, -1)
      expect(ends.map { it.values_at("StopID", "CarOnStop") }).to eq([ %w[91000 1], %w[91004 0] ])
    end

    it "跨午夜：TEST-0002 23:40 從起站離站，隔天 00:50 到末站" do
      ends = found("TEST-0002", "2026-10-19 23:40:00", "StopID", "file") + found("TEST-0002", "2026-10-20 00:50:00", "StopID", "file")
      expect(ends).to eq([ %w[91000 2026-10-19/23.jsonl], %w[91004 2026-10-20/00.jsonl] ])
    end

    it "前一晚發車：TEST-0004 前一天 23:30 從起站離站，尾巴到 00:20" do
      ends = found("TEST-0004", "2026-10-18 23:30:00", "StopID", "file") + found("TEST-0004", "00:20:00", "StopID", "file")
      expect(ends).to eq([ %w[91000 2026-10-18/23.jsonl], %w[91004 2026-10-19/00.jsonl] ])
    end

    it "終點站停留跨午夜：TEST-0003 22:59 過倒數第二站、23:05 到末站、00:02 從末站離站" do
      times = [ "2026-10-18 22:59:00", "2026-10-18 23:05:00", "2026-10-19 00:02:00" ]
      expect(times.flat_map { found("TEST-0003", it, "StopID", "CarOnStop", "file") }).to eq(
        [ %w[91008 0 2026-10-18/22.jsonl], %w[91009 1 2026-10-18/23.jsonl], %w[91009 0 2026-10-19/00.jsonl] ]
      )
    end

    it "隔天 01 時發車：TEST-0004 隔天 01:10 從返程起站離站" do
      expect(found("TEST-0004", "2026-10-20 01:10:00", "StopID", "CarOnStop", "file")).to eq([ %w[91005 0 2026-10-20/01.jsonl] ])
    end

    it "視窗外的兩個檔各有一筆路線 9001 的事件" do
      outside = records.select { %w[2026-10-18/21.jsonl 2026-10-20/02.jsonl].include?(it["file"]) }
      expect(outside.map { it.values_at("file", "RouteID") }).to eq([ %w[2026-10-18/21.jsonl 9001], %w[2026-10-20/02.jsonl 9001] ])
    end

    it "換 GoBack：TEST-0001 06:52 去程離站後，下一筆是返程" do
      expect(slice("TEST-0001", "06:52:00", "06:58:00").map { it["GoBack"] }).to eq(%w[0 1])
    end

    it "同方向站序回頭：TEST-0003 去程到末站後，下一趟去程從起站開始" do
      expect(slice("TEST-0003", "07:53:00", "08:05:00").map { it.values_at("GoBack", "StopID") }).to eq(
        [ %w[0 91004], %w[0 91004], %w[0 91000] ]
      )
    end

    it "同方向中斷 65 分鐘：TEST-0003 返程 09:22:30 之後下一筆在 10:27:30" do
      expect(slice("TEST-0003", "09:22:30", "10:27:30").map { it["DataTime"][11, 8] }).to eq(%w[09:22:30 10:27:30])
    end

    it "同站先到後離：TEST-0001 06:50 到末站、06:52 離站" do
      expect(slice("TEST-0001", "06:50:00", "06:52:00").map { it.values_at("StopID", "CarOnStop") }).to eq([ %w[91004 1], %w[91004 0] ])
    end

    it "跨小時檔的重複：TEST-0001 07:59:58 同時在 07.jsonl 與 08.jsonl.gz" do
      expect(found("TEST-0001", "07:59:58", "file")).to eq([ [ "2026-10-19/07.jsonl" ], [ "2026-10-19/08.jsonl.gz" ] ])
    end

    it "StopID 不在該方向：TEST-0003 08:26 去程事件掛的是返程的站牌" do
      expect(found("TEST-0003", "08:26:00", "GoBack", "StopID")).to eq([ %w[0 91007] ])
    end

    it "RouteID 9002 與 9001 混在同一趟：TEST-0001 08:40 起的去程" do
      expect(slice("TEST-0001", "08:40:00", "09:31:00").map { it["RouteID"] }.tally).to eq("9002" => 4, "9001" => 6)
    end

    it "整趟只掛附屬路線 9002 或 9003 的事件各有一段" do
      routes = [ slice("TEST-0004", "07:10:00", "08:04:00"), slice("TEST-0003", "09:05:00", "09:22:30") ]
      expect(routes.map { |rows| rows.map { it["RouteID"] }.uniq }).to eq([ %w[9002], %w[9003] ])
    end

    it "DutyStatus 2 有三筆落在趟末、一筆在趟中，另有一筆在非營運事件上" do
      twos = records.select { it["DutyStatus"] == "2" }.map { it.values_at("BusID", "DataTime", "RouteID") }
      expect(twos.sort).to eq([ [ "TEST-0001", "2026-10-19 17:56:00", "9001" ], [ "TEST-0002", "2026-10-20 00:50:00", "9001" ],
                               [ "TEST-0003", "2026-10-19 11:27:00", "9001" ], [ "TEST-0003", "2026-10-19 13:09:00", "9001" ],
                               [ "TEST-0004", "2026-10-19 15:00:00", "0" ] ])
    end

    def on_control_route(bus) = records.select { it.values_at("BusID", "RouteID") == [ bus, "9100" ] }.map { it.values_at("DataTime", "StopID", "file") }

    it "兩趟之間跑了別的路線：TEST-0002 14:10 到 14:30 在對照路線 9100 經過三個站，都在 14 時檔" do
      expect(on_control_route("TEST-0002")).to eq([ [ "2026-10-19 14:10:00", "92000", "2026-10-19/14.jsonl" ], [ "2026-10-19 14:20:00", "92001", "2026-10-19/14.jsonl" ],
                                                     [ "2026-10-19 14:30:00", "92002", "2026-10-19/14.jsonl" ] ])
    end

    it "在末站切路線碼：TEST-0001 15:50 到 15:55 在對照路線 9100 只有兩個站，都在 15 時檔" do
      expect(on_control_route("TEST-0001")).to eq([ [ "2026-10-19 15:50:00", "92000", "2026-10-19/15.jsonl" ], [ "2026-10-19 15:51:00", "92000", "2026-10-19/15.jsonl" ],
                                                     [ "2026-10-19 15:55:00", "92001", "2026-10-19/15.jsonl" ] ])
    end

    it "16 時的小時檔是空的" do
      expect(File.size(File.join(DuckdbHelpers::FIXTURE_DATA, "bus_event/2026-10-19/16.jsonl"))).to eq(0)
    end
  end

  describe "bus_seat_event" do
    let(:records) { feed_records("bus_seat_event") }

    def counts(bus, from, to) = slice(bus, from, to).map { it.values_at("StopID", "CarOnStop", "RemainingNum") }

    it "小時檔跟 bus_event 同一組，全部是 .jsonl" do
      expect(feed_files("bus_seat_event")).to eq(window_hours.map { "#{it}.jsonl" })
    end

    it "同一站有到站 11 與離站 14 兩筆：TEST-0001 08:54" do
      expect(counts("TEST-0001", "08:54:00", "08:54:30")).to eq([ [ "91001", "1", 11 ], [ "91001", "0", 14 ] ])
    end

    it "漏一站：TEST-0001 10:41 起的去程在第三個站沒有人數" do
      expect(counts("TEST-0001", "10:41:00", "11:30:00")).to eq(
        [ [ "91000", "0", 0 ], [ "91001", "0", 5 ], [ "91002", "0", 10 ], [ "91004", "1", 7 ] ]
      )
    end

    it "趟末之後 3 分鐘多一筆：TEST-0001 11:33" do
      expect(counts("TEST-0001", "11:30:01", "12:00:00")).to eq([ [ "91004", "0", 0 ] ])
    end

    it "起站歸零與不歸零各有：TEST-0001 06:00 是 0，08:42 是 3" do
      expect(counts("TEST-0001", "06:00:00", "06:00:00") + counts("TEST-0001", "08:42:00", "08:42:00")).to eq(
        [ [ "91000", "0", 0 ], [ "91000", "0", 3 ] ]
      )
    end

    it "起站上客前是 0、離站是 3：TEST-0001 08:42 那趟的起站 91000" do
      expect(counts("TEST-0001", "08:40:00", "08:42:00")).to eq([ [ "91000", "1", 0 ], [ "91000", "0", 3 ] ])
    end

    it "起點前 61 分鐘才有起站的到站記錄：TEST-0002 17:10 那趟，16:09 在 91000" do
      expect(counts("TEST-0002", "16:00:00", "17:10:00")).to eq([ [ "91000", "1", 4 ] ])
    end

    it "只有一筆負值：TEST-0002 07:11:30" do
      negatives = records.select { it["RemainingNum"].negative? }
      expect(negatives.map { it.values_at("BusID", "DataTime", "RemainingNum") }).to eq([ [ "TEST-0002", "2026-10-19 07:11:30", -1 ] ])
    end

    it "一次跳動超過 30：TEST-0002 11:32:30 是 3，下一站 11:44:30 是 40" do
      expect(counts("TEST-0002", "11:32:30", "11:44:30")).to eq([ [ "91006", "0", 3 ], [ "91007", "0", 40 ] ])
    end

    it "跨小時檔的重複有兩組：TEST-0001 07:59:58 與 TEST-0002 06:59:30" do
      dups = [ %w[TEST-0001 07:59:58], %w[TEST-0002 06:59:30] ].map { |bus, at| slice(bus, at, at).map { it["file"] } }
      expect(dups).to eq([ %w[2026-10-19/07.jsonl 2026-10-19/08.jsonl], %w[2026-10-19/06.jsonl 2026-10-19/07.jsonl] ])
    end
  end
end
