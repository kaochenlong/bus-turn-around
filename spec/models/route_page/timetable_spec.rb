require "rails_helper"

RSpec.describe RoutePage::Timetable, type: :model do
  # A stored day of route 9001 whose stops run 甲站 to 乙站 outbound and back.
  def store_day(day = Date.new(2026, 10, 19), first_stops: %w[甲站 乙站])
    create(:route_day, day:).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: first_stops[0] }, { go_back: 0, seq: 4, stop_name: first_stops[1] },
                                { go_back: 1, seq: 5, stop_name: first_stops[1] }, { go_back: 1, seq: 9, stop_name: first_stops[0] } ])
    end
  end

  let(:route_day) { store_day }

  # A complete trip starting at `start` on the day that runs for `minutes`.
  def trip(start, minutes, go_back: 0, route_day: self.route_day)
    start_time = Time.zone.parse("#{route_day.day} #{start}")
    route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + minutes.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  # A layover of `minutes` after a trip of direction `go_back` ending at `end_at`.
  def layover(end_at, minutes, go_back:)
    end_time = Time.zone.parse("2026-10-19 #{end_at}")
    route_day.layovers.create!(bus_id: "TEST-0001", go_back:, end_time:, next_start_time: end_time + (minutes * 60).seconds)
  end

  # The spec's four departures: direction 0 at 06:00 and 06:30 running 50
  # minutes, direction 1 at 07:00 and 07:30 running 45 minutes.
  def four_departures
    trip("06:00", 50).then { trip("06:30", 50) }
    trip("07:00", 45, go_back: 1).then { trip("07:30", 45, go_back: 1) }
  end

  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  def timetable(*days, ends: route_ends("stop", "stop"), buffer: 15, percentile: 85)
    days = [ route_day ] if days.empty?
    described_class.new(route_days: RouteDay.where(id: days.map(&:id)), ends:, buffer:, percentile:)
  end

  it "發車數是量到的每小時數：去程 06 時 2 班，去程其他小時 0" do
    four_departures
    expect([ timetable.departures.dig(0, 6), timetable.departures.fetch(0).values.sum ]).to eq([ 2, 2 ])
  end

  it "兩端都停車時，兩端的停留都是休息分鐘數" do
    expect(timetable(buffer: 10).holds).to eq(0 => 10, 1 => 10)
  end

  it "直接折返那一端停量到的折返停留中位數，四捨五入到整分鐘：去程結束的折返停留 1.8 與 2.0 分鐘，停 2 分鐘" do
    layover("06:50", 1.8, go_back: 0).then { layover("07:50", 2.0, go_back: 0) }
    expect(timetable(ends: route_ends("pass_through", "stop")).holds).to eq(0 => 2, 1 => 15)
  end

  it "直接折返那一端沒有量到折返停留時停 0 分鐘" do
    expect(timetable(ends: route_ends("pass_through", "stop")).holds).to eq(0 => 0, 1 => 15)
  end

  it "站名是各方向的第一站，只讀這一頁路線自己的站：成員路線 9050 的己站不算" do
    route_day.stops.create!(route_id: 9050, go_back: 0, seq: 0, stop_name: "己站")
    expect(timetable.stop_names).to eq(0 => "甲站", 1 => "乙站")
  end

  it "涵蓋好幾天時站名取最新那一天的：10-19 是甲站與乙站，10-20 是丙站與丁站" do
    later = store_day(Date.new(2026, 10, 20), first_stops: %w[丙站 丁站])
    expect(timetable(route_day, later).stop_names).to eq(0 => "丙站", 1 => "丁站")
  end

  it "頁首要的：涵蓋的日子、路線名、量到的平均每天車數（照換休息試算的算法）" do
    four_departures
    expect([ timetable.covered.map(&:day), timetable.route_name, timetable.vehicles_per_day ]).to eq([ [ Date.new(2026, 10, 19) ], "測試幹線", 1.0 ])
  end

  it "超時比例表每個百分位數一列，用的是班表的休息分鐘數：四趟都剛好等於計畫值時沒有一趟超時" do
    four_departures
    expect([ timetable.overruns.map(&:percentile), timetable.overruns.map(&:overrun_share).uniq ]).to eq([ [ 50, 55, 60, 65, 70, 75, 80, 85, 90, 95 ], [ 0.0 ] ])
  end

  it "某方向沒有任何行駛時間：missing_run_times 列出那個方向" do
    trip("06:00", 50)
    expect(timetable.missing_run_times).to eq([ 1 ])
  end

  describe "#data：給瀏覽器的資料" do
    before { four_departures }

    let(:data) { timetable(buffer: 10, percentile: 50).data }

    it "帶著初始的百分位數與休息、百分位數的選項、休息與發車數的範圍" do
      expect(data.slice("percentile", "buffer", "percentiles", "bufferRange", "departuresRange"))
        .to eq("percentile" => 50, "buffer" => 10, "percentiles" => [ 50, 55, 60, 65, 70, 75, 80, 85, 90, 95 ], "bufferRange" => [ 0, 20 ], "departuresRange" => [ 0, 30 ])
    end

    it "每方向 24 個小時量到的發車數：去程 06 時 2、返程 07 時 2，其他 0" do
      expect([ data["departures"]["0"].size, data["departures"]["0"][6], data["departures"]["1"][7], data["departures"].values.flatten.sum ]).to eq([ 24, 2, 2, 4 ])
    end

    it "每方向每小時每個百分位數的計畫行駛時間與退回標記：四班例子每一格都是退回全天的 50 或 45" do
      cells = data["runTimes"]
      expect([ cells["0"].size, cells["0"][6].keys, cells["0"][6]["85"], cells["1"][23]["50"], cells["0"].flat_map(&:values).uniq, cells["1"].flat_map(&:values).uniq ])
        .to eq([ 24, %w[50 55 60 65 70 75 80 85 90 95], [ 50, true ], [ 45, true ], [ [ 50, true ] ], [ [ 45, true ] ] ])
    end

    it "兩端的停留與站名，鍵是方向的字串；兩端都停車時 stoppingEnds 是兩個方向" do
      expect([ data["holds"], data["stoppingEnds"], data["stopNames"] ]).to eq([ { "0" => 10, "1" => 10 }, [ 0, 1 ], { "0" => "甲站", "1" => "乙站" } ])
    end

    it "去程直接折返時：那一端的停留是量到的中位數、stoppingEnds 只有方向 1，瀏覽器換休息時只動方向 1 的停留" do
      layover("06:50", 1.8, go_back: 0).then { layover("07:50", 2.0, go_back: 0) }
      pass_through = timetable(ends: route_ends("pass_through", "stop"), buffer: 10).data
      expect([ pass_through["holds"], pass_through["stoppingEnds"] ]).to eq([ { "0" => 2, "1" => 10 }, [ 1 ] ])
    end
  end

  it "資料裡有五趟以上的小時用那一小時的值、不標退回：06 時五趟 44、47、50、52、60 的 p85 是 55；沒有趟次的 12 時退回全天的 55" do
    [ 44, 47, 50, 52, 60 ].each_with_index { |minutes, index| trip(format("06:%02d", index * 10), minutes) }
    trip("07:00", 45, go_back: 1)
    cells = timetable.data["runTimes"]["0"]
    expect([ cells[6]["85"], cells[12]["85"], cells[6]["50"] ]).to eq([ [ 55, false ], [ 55, true ], [ 50, false ] ])
  end

  describe ".percentile" do
    it "沒給時是 85；給了 50 到 95 每 5 一格裡的值就用它" do
      expect([ described_class.percentile(nil), described_class.percentile(""), described_class.percentile("50") ]).to eq([ 85, 85, 50 ])
    end

    [ "83", "100", "45", "abc", "85.0", [ "85" ] ].each do |param|
      it "#{param.inspect} 不收" do
        expect { described_class.percentile(param) }.to raise_error(RoutePage::Coverage::InvalidParameter)
      end
    end
  end
end
