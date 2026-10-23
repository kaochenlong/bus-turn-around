require "rails_helper"
require_relative "../../support/duckdb"

RSpec.describe RoutePage::Cycles, type: :model do
  let(:route_day) do
    create(:route_day)
  end

  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  # Ordered by day like RoutePage::Coverage#route_days, which the page passes in.
  def cycles(ends: route_ends("stop", "stop"), days: [ route_day ]) = described_class.new(RouteDay.where(id: days.map(&:id)).order(:day), ends:)

  # A clock time ("HH:MM") on the stored day, Taipei time.
  def at(time, on = route_day) = Time.zone.parse("#{on.day} #{time}")

  # The clock time `minutes` after the clock time `time`.
  def later(time, minutes) = (Time.zone.parse("2026-10-19 #{time}") + minutes.minutes).strftime("%H:%M")

  # A trip of a vehicle from `start` to `finish` on the stored day `on`;
  # other attributes default to a complete direction 0 trip that leaves with
  # an observed departure and ends with an observed arrival.
  def trip(start, finish, go_back: 0, bus_id: "TEST-0001", on: route_day, **attributes)
    on.trips.create!({ bus_id:, path_attribute_id: 9001, go_back:, band: "other", start_time: at(start, on), end_time: at(finish, on),
                       first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                       start_from_arrival: false, end_from_departure: false }.merge(attributes))
  end

  # A stored layover from a trip of direction `go_back` ending at `end_time`
  # to the vehicle's next trip starting at `next_start`.
  def layover(end_time, next_start, go_back: 0, bus_id: "TEST-0001", on: route_day)
    on.layovers.create!(bus_id:, go_back:, end_time: at(end_time, on), next_start_time: at(next_start, on))
  end

  # The spec's qualifying pair: a lead trip 06:00–06:50, a stored layover of
  # the lead direction 06:50–07:00 and a back trip 07:00–08:30.
  def qualifying_pair(lead: {}, back: {})
    trip("06:00", "06:50", **lead)
    layover("06:50", "07:00")
    trip("07:00", "08:30", go_back: 1, **back)
  end

  # The spec's qualifying chain, one vehicle for every link unless `buses`
  # gives five: a back trip 07:00–08:30, a stored layover of its direction
  # 08:30–08:42, a lead trip 08:42–09:30, a stored layover of its direction
  # 09:30–09:43 and a back trip 09:43–10:31. Each layover takes the direction
  # of the trip it follows.
  def qualifying_chain(earlier: {}, lead: {}, later: {}, buses: [ "TEST-0001" ] * 5)
    trip("07:00", "08:30", go_back: 1, bus_id: buses[0], **earlier)
    layover("08:30", "08:42", go_back: earlier.fetch(:go_back, 1), bus_id: buses[1])
    trip("08:42", "09:30", bus_id: buses[2], **lead)
    layover("09:30", "09:43", go_back: lead.fetch(:go_back, 0), bus_id: buses[3])
    trip("09:43", "10:31", go_back: 1, bus_id: buses[4], **later)
  end

  # Vehicle `bus_id`'s lead trip leaving at `start` (with the attributes in
  # `lead`), the stored layover after it and a back trip ending `minutes`
  # after `start`: a round trip of `minutes`. With `stay`, also the back trip
  # before it, which ended `stay` minutes before `start`, so the trips make a
  # cycle of `stay` + `minutes` as well.
  def loop_of(bus_id, start, minutes, stay: nil, lead: {}, on: route_day)
    earlier_back_trip(bus_id, start, stay, on:) if stay
    trip(start, later(start, 40), bus_id:, on:, **lead)
    layover(later(start, 40), later(start, 50), bus_id:, on:)
    trip(later(start, 50), later(start, minutes), go_back: 1, bus_id:, on:)
  end

  # A back trip ending `stay` minutes before `start`, and the stored layover
  # from it to the trip leaving at `start`.
  def earlier_back_trip(bus_id, start, stay, on:)
    trip(later(start, -stay - 50), later(start, -stay), go_back: 1, bus_id:, on:)
    layover(later(start, -stay), start, go_back: 1, bus_id:, on:)
  end

  # The SQL of the queries that read layovers while the block runs.
  def layover_queries(&)
    queries = []
    record = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?("FROM layovers") }
    ActiveSupport::Notifications.subscribed(record, "sql.active_record", &)
    queries
  end

  # Every hour with round trips, as [hour, count, [p50, p85]].
  def round_trip_rows(...) = cycles(...).rows.select { it.n_round_trips.positive? }.map { [ it.hour, it.n_round_trips, it.round_trip_percentiles ] }

  # Every hour with cycles, as [hour, count, [p10, p50]].
  def cycle_rows(...) = cycles(...).rows.select { it.n_cycles.positive? }.map { [ it.hour, it.n_cycles, it.cycle_percentiles ] }

  describe "前段方向" do
    [ %w[pass_through stop 0 1], %w[stop pass_through 1 0], %w[stop stop 0 1], %w[pass_through pass_through 0 1] ].each do |outbound, inbound, lead, back|
      it "去程結束那一端是 #{outbound}、返程結束那一端是 #{inbound}：前段方向 #{lead}，後段方向 #{back}" do
        cycles = cycles(ends: route_ends(outbound, inbound))
        expect([ cycles.lead_go_back, cycles.back_go_back ]).to eq([ lead.to_i, back.to_i ])
      end
    end
  end

  describe "來回一趟" do
    it "前段 06:00 離站，折返停留 06:50 到 07:00，後段 08:30 到站：6 時一筆 150.0 分鐘" do
      qualifying_pair
      expect(round_trip_rows).to eq([ [ 6, 1, [ 150.0, 150.0 ] ] ])
    end

    it "前段的起點是到站時刻：不算來回" do
      qualifying_pair(lead: { start_from_arrival: true })
      expect(round_trip_rows).to eq([])
    end

    it "後段的終點是離站時刻：不算來回" do
      qualifying_pair(back: { end_from_departure: true })
      expect(round_trip_rows).to eq([])
    end

    it "前段漏了起站：不算來回" do
      qualifying_pair(lead: { completeness: "missing_start" })
      expect(round_trip_rows).to eq([])
    end

    it "後段漏了末站：不算來回" do
      qualifying_pair(back: { completeness: "missing_end" })
      expect(round_trip_rows).to eq([])
    end

    it "兩趟之間沒有寫入的折返停留：前段 07:23 到站、後段 07:40 發車，不算來回" do
      trip("06:35", "07:23")
      trip("07:40", "08:16", go_back: 1)
      expect(round_trip_rows).to eq([])
    end

    it "時刻對得上的折返停留與後段是別台車的：不算來回" do
      trip("06:00", "06:50")
      layover("06:50", "07:00", bus_id: "TEST-0002")
      trip("07:00", "08:30", go_back: 1, bus_id: "TEST-0002")
      expect(round_trip_rows).to eq([])
    end

    it "折返停留接到的時刻有別台車的後段發車：不算來回" do
      trip("06:00", "06:50")
      layover("06:50", "07:00")
      trip("07:00", "08:30", go_back: 1, bus_id: "TEST-0002")
      expect(round_trip_rows).to eq([])
    end

    it "連跑兩趟後段方向：不算來回" do
      trip("07:00", "08:30", go_back: 1)
      layover("08:30", "08:40", go_back: 1)
      trip("08:40", "10:00", go_back: 1)
      expect(round_trip_rows).to eq([])
    end

    it "折返停留接到的下一趟又是前段方向：07:53 到站的前段不算來回" do
      trip("07:05", "07:53")
      layover("07:53", "08:08")
      trip("08:08", "08:56")
      expect(round_trip_rows).to eq([])
    end

    it "前段是返程的路線：從返程發車算到去程到站" do
      trip("06:00", "06:50", go_back: 1)
      layover("06:50", "07:00", go_back: 1)
      trip("07:00", "08:30")
      expect(round_trip_rows(ends: route_ends("stop", "pass_through"))).to eq([ [ 6, 1, [ 150.0, 150.0 ] ] ])
    end
  end

  describe "週期" do
    # The links of the qualifying chain, in order.
    links = %w[前一個後段 停車端的折返停留 前段 另一端的折返停留 下一個後段]

    it "前一個後段 08:30 到站，停留到 08:42，前段發車，下一個後段 10:31 到站：8 時一筆 121.0，等於停留 12.0 加來回 109.0" do
      qualifying_chain
      expect([ cycle_rows, round_trip_rows ]).to eq([ [ [ 8, 1, [ 121.0, 121.0 ] ] ], [ [ 8, 1, [ 109.0, 109.0 ] ] ] ])
    end

    it "前一個後段 06:58 到站、前段 07:15 發車：週期算在前段發車的 7 時" do
      trip("06:10", "06:58", go_back: 1)
      layover("06:58", "07:15", go_back: 1)
      trip("07:15", "08:03").then { layover("08:03", "08:15") }
      trip("08:15", "09:03", go_back: 1)
      expect(cycle_rows).to eq([ [ 7, 1, [ 125.0, 125.0 ] ] ])
    end

    it "一台車當天第一趟就是前段：那一趟跟接著的後段算一筆來回，沒有週期" do
      qualifying_pair
      expect([ round_trip_rows, cycle_rows ]).to eq([ [ [ 6, 1, [ 150.0, 150.0 ] ] ], [] ])
    end

    it "前一個後段的終點是離站時刻：不算週期" do
      qualifying_chain(earlier: { end_from_departure: true })
      expect(cycle_rows).to eq([])
    end

    it "下一個後段漏了末站：不算週期" do
      qualifying_chain(later: { completeness: "missing_end" })
      expect(cycle_rows).to eq([])
    end

    it "下一個後段的終點是離站時刻：不算週期" do
      qualifying_chain(later: { end_from_departure: true })
      expect(cycle_rows).to eq([])
    end

    it "前段的起點是到站時刻：照樣算週期，同樣這幾趟不算來回" do
      qualifying_chain(lead: { start_from_arrival: true })
      expect([ cycle_rows, round_trip_rows ]).to eq([ [ [ 8, 1, [ 121.0, 121.0 ] ] ], [] ])
    end

    it "前段漏了起站：照樣算週期" do
      qualifying_chain(lead: { completeness: "missing_start" })
      expect(cycle_rows).to eq([ [ 8, 1, [ 121.0, 121.0 ] ] ])
    end

    it "前一個後段漏了起站、終點是實際到站：照樣算週期" do
      qualifying_chain(earlier: { completeness: "missing_start" })
      expect(cycle_rows).to eq([ [ 8, 1, [ 121.0, 121.0 ] ] ])
    end

    (1..4).each do |split|
      it "從#{links[split]}起換成另一台車：不算週期" do
        qualifying_chain(buses: ([ "TEST-0001" ] * split) + ([ "TEST-0002" ] * (5 - split)))
        expect(cycle_rows).to eq([])
      end
    end

    it "從前段方向的折返停留開始（連跑兩趟前段）：不算週期" do
      qualifying_chain(earlier: { go_back: 0 })
      expect(cycle_rows).to eq([])
    end

    it "中間那趟也是後段方向：不算週期" do
      qualifying_chain(lead: { go_back: 1 })
      expect(cycle_rows).to eq([])
    end

    it "接在後面的又是前段方向：不算週期" do
      qualifying_chain(later: { go_back: 0 })
      expect(cycle_rows).to eq([])
    end
  end

  describe "按發車小時彙總" do
    let(:empty_row) do
      described_class::Row.new(hour: nil, n_round_trips: 0, round_trip_percentiles: [ nil, nil ], n_cycles: 0, cycle_percentiles: [ nil, nil ])
    end

    it "6 時只有一筆 150 分鐘的來回、沒有週期：來回 1 筆、p50 與 p85 都是 150.0、樣本少，週期 0 筆、百分位數是 nil" do
      qualifying_pair
      row = cycles.rows.sole
      expect([ row.hour, row.n_round_trips, row.round_trip_percentiles, row.round_trip_small_sample?, row.n_cycles, row.cycle_percentiles ])
        .to eq([ 6, 1, [ 150.0, 150.0 ], true, 0, [ nil, nil ] ])
    end

    it "來回 108、108、109、113、125、150、153，週期 121、125、136、146、163：全天來回 7 筆 p50 113.0、p85 150.3，週期 5 筆 p10 122.6、p50 136.0" do
      [ [ 108, 13 ], [ 108, 17 ], [ 109, 27 ], [ 113, 33 ], [ 125, 38 ], [ 150 ], [ 153 ] ].each_with_index do |(minutes, stay), index|
        loop_of("TEST-#{index}", "08:00", minutes, stay:)
      end
      total = cycles.total
      expect([ total.n_round_trips, total.round_trip_percentiles, total.n_cycles, total.cycle_percentiles ]).to eq([ 7, [ 113.0, 150.3 ], 5, [ 122.6, 136.0 ] ])
    end

    it "全天那一列的小時是 nil，合併每個小時：6 時 150、8 時 110 的來回是 2 筆 p50 130.0、p85 144.0，8 時 121 的週期是 1 筆" do
      loop_of("TEST-0001", "06:00", 150).then { loop_of("TEST-0002", "08:41", 110, stay: 11) }
      summary = cycles
      expect([ summary.rows.map(&:hour), summary.total ])
        .to eq([ [ 6, 8 ], empty_row.with(n_round_trips: 2, round_trip_percentiles: [ 130.0, 144.0 ], n_cycles: 1, cycle_percentiles: [ 121.0, 121.0 ]) ])
    end

    it "第一天 7 時兩筆來回 100 與 110、第二天 7 時一筆 120，涵蓋兩天：7 時 3 筆、p50 110.0，不是兩天各自的值再合" do
      second_day = create(:route_day, day: Date.new(2026, 10, 20))
      loop_of("TEST-0001", "07:00", 100).then { loop_of("TEST-0002", "07:10", 110) }
      loop_of("TEST-0001", "07:00", 120, on: second_day)
      row = cycles(days: [ route_day, second_day ]).rows.sole
      expect([ row.hour, row.n_round_trips, row.round_trip_percentiles.first ]).to eq([ 7, 3, 110.0 ])
    end

    it "7 時 4 筆來回、6 筆週期：來回標成樣本少，週期不標" do
      6.times { |index| loop_of("TEST-#{index}", "07:00", 110, stay: 10, lead: { start_from_arrival: index < 2 }) }
      row = cycles.rows.sole
      expect([ row.n_round_trips, row.round_trip_small_sample?, row.n_cycles, row.cycle_small_sample? ]).to eq([ 4, true, 6, false ])
    end

    it "剛好 5 筆不算樣本少，門檻跟行駛時間同一個" do
      5.times { |index| loop_of("TEST-#{index}", "07:00", 110, stay: 10) }
      row = cycles.rows.sole
      expect([ row.n_round_trips, row.round_trip_small_sample?, row.n_cycles, row.cycle_small_sample?, RoutePage::RunTimes::SMALL_SAMPLE ]).to eq([ 5, false, 5, false, 5 ])
    end

    it "只有一趟漏了末站、沒有折返停留：沒有小時的列，全天那一列兩個量都是 0 筆、百分位數 nil，也就沒有來回" do
      trip("06:00", "06:40", completeness: "missing_end")
      summary = cycles
      expect([ summary.rows, summary.total, summary.any_round_trips? ]).to eq([ [], empty_row, false ])
    end

    it "有一筆來回時 any_round_trips? 是真" do
      qualifying_pair
      expect(cycles.any_round_trips?).to be(true)
    end

    it "同一個物件呼叫 rows、total 與 any_round_trips? 各兩次，只查一次" do
      qualifying_pair
      summary = cycles
      expect(layover_queries { 2.times { [ summary.rows, summary.total, summary.any_round_trips? ] } }.size).to eq(1)
    end
  end

  describe "說明用的站名" do
    # The first and last stop of each direction on a stored day.
    def add_stops(day, outbound, inbound)
      day.stops.create!([ { go_back: 0, seq: 0, stop_name: outbound.first }, { go_back: 0, seq: 4, stop_name: outbound.last },
                          { go_back: 1, seq: 5, stop_name: inbound.first }, { go_back: 1, seq: 9, stop_name: inbound.last } ])
    end

    it "取涵蓋的日子裡最新的 2026-10-20：前段的第一個站牌甲站、後段的最後一個站牌戊站" do
      second_day = create(:route_day, day: Date.new(2026, 10, 20))
      add_stops(route_day, %w[乙站 丙站], %w[丙站 乙站]).then { add_stops(second_day, %w[甲站 丁站], %w[丁站 戊站]) }
      summary = cycles(days: [ route_day, second_day ])
      expect([ summary.first_stop_name, summary.last_stop_name ]).to eq(%w[甲站 戊站])
    end

    it "前段是返程的路線：返程的第一個站牌與去程的最後一個站牌" do
      add_stops(route_day, %w[甲站 丁站], %w[戊站 乙站])
      summary = cycles(ends: route_ends("stop", "pass_through"))
      expect([ summary.first_stop_name, summary.last_stop_name ]).to eq(%w[戊站 丁站])
    end

    it "最新一天沒有站牌（之前寫入的資料）：站名是 nil" do
      summary = cycles
      expect([ summary.first_stop_name, summary.last_stop_name ]).to eq([ nil, nil ])
    end
  end

  describe "另一端是不是停車" do
    [ [ "stop", "stop", true ], [ "pass_through", "stop", false ], [ "stop", "pass_through", false ], [ "pass_through", "pass_through", false ] ]
      .each do |outbound, inbound, stopping|
        it "去程結束那一端是 #{outbound}、返程結束那一端是 #{inbound}：#{stopping ? '前段結束的那一端停車' : '前段結束的那一端開過去就走'}" do
          expect(cycles(ends: route_ends(outbound, inbound)).far_end_stopping?).to be(stopping)
        end
      end
  end

  describe "fixture 寫入的 9001 2026-10-19（兩端都停車）", :duckdb do
    let(:fixture_cycles) do
      RouteDayLoader.new(route_id: 9001, day: Date.new(2026, 10, 19), data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb").call
      described_class.new(RouteDay.where(route_id: 9001, day: Date.new(2026, 10, 19)), ends: route_ends("stop", "stop"))
    end

    it "全天那一列：來回 7 筆、p50 113.0、p85 150.3，週期 5 筆、p10 122.6、p50 136.0" do
      total = fixture_cycles.total
      expect([ total.n_round_trips, total.round_trip_percentiles, total.n_cycles, total.cycle_percentiles ]).to eq([ 7, [ 113.0, 150.3 ], 5, [ 122.6, 136.0 ] ])
    end

    it "每個發車小時的來回與週期：6 時與 17 時沒有週期，其他小時各一筆" do
      rows = fixture_cycles.rows.map { [ it.hour, it.n_round_trips, it.round_trip_percentiles.first, it.n_cycles, it.cycle_percentiles.last ] }
      expect(rows).to eq([ [ 6, 1, 150.0, 0, nil ], [ 7, 1, 108.0, 1, 125.0 ], [ 8, 1, 109.0, 1, 121.0 ], [ 10, 1, 153.0, 1, 163.0 ],
                           [ 11, 1, 113.0, 1, 136.0 ], [ 13, 1, 125.0, 1, 146.0 ], [ 17, 1, 108.0, 0, nil ] ])
    end

    it "每個小時的列，來回與週期都是樣本少" do
      expect(fixture_cycles.rows.map { [ it.round_trip_small_sample?, it.cycle_small_sample? ] }.uniq).to eq([ [ true, true ] ])
    end
  end
end
