require "rails_helper"

RSpec.describe RoutePage::PlannedRunTimes, type: :model do
  let(:route_day) { create(:route_day) }

  # A complete trip starting at `start` on 2026-10-19 that runs for `minutes`,
  # unless attributes say otherwise.
  def trip(start, minutes, go_back: 0, **attributes)
    start_time = Time.zone.parse("2026-10-19 #{start}")
    route_day.trips.create!({ bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:,
                              end_time: start_time + minutes.minutes, first_seq: 0, last_seq: 4, n_events: 10,
                              n_stops_observed: 5, completeness: "complete", start_from_arrival: false,
                              end_from_departure: false }.merge(attributes))
  end

  # The spec's five run times of direction 0 in the 06 hour: 44, 47, 50, 52 and 60.
  def five_trips = [ 44, 47, 50, 52, 60 ].each_with_index { |minutes, index| trip(format("06:%02d", index * 10), minutes) }

  def planned(percentile: 85) = described_class.new(RouteDay.where(id: route_day.id), percentile:)

  # The spec's example "Percentiles of the same five run times".
  [ [ 50, 50 ], [ 85, 55 ], [ 95, 58 ] ].each do |percentile, minutes|
    it "06 時五趟 44、47、50、52、60：p#{percentile} 的計畫行駛時間是 #{minutes} 分鐘，不是退回全天" do
      five_trips
      expect(planned(percentile:).minutes(0, 6)).to eq([ minutes, false ])
    end
  end

  it "選 85 的物件也答得出其他百分位數：p50 是 50、p95 是 58" do
    five_trips
    expect([ planned.minutes_at(0, 6, 50), planned.minutes_at(0, 6, 95) ]).to eq([ [ 50, false ], [ 58, false ] ])
  end

  it "返程 22 時只有兩趟 40 與 50：p50 不是那兩趟的 45，退回全天七趟的 50 並標記" do
    five_trips.then { [ 44, 47, 50, 52, 60 ].each_with_index { |minutes, index| trip(format("07:%02d", index * 10), minutes, go_back: 1) } }
    trip("22:00", 40, go_back: 1).then { trip("22:30", 50, go_back: 1) }
    expect(planned(percentile: 50).minutes(1, 22)).to eq([ 50, true ])
  end

  it "那一小時一趟都沒有時也退回全天：12 時用 06 時那五趟的 p85 55" do
    five_trips
    expect(planned.minutes(0, 12)).to eq([ 55, true ])
  end

  it "半分鐘進位：兩趟 50 與 55 的 p50 是 52.5，計畫行駛時間 53" do
    trip("08:00", 50).then { trip("08:30", 55) }
    expect(planned(percentile: 50).minutes(0, 8)).to eq([ 53, true ])
  end

  it "行駛時間的趟次跟 run-time 一樣：不完整、起點用到站時刻、終點用離站時刻的趟次都不算，p95 仍是 58" do
    five_trips
    trip("06:50", 100, start_from_arrival: true).then { trip("06:55", 100, end_from_departure: true) }
    trip("06:57", 100, completeness: "missing_end")
    expect(planned(percentile: 95).minutes(0, 6)).to eq([ 58, false ])
  end

  it "沒有任何行駛時間的方向回 nil、any? 是 false；有的方向 any? 是 true" do
    five_trips
    expect([ planned.minutes(1, 6), planned.any?(1), planned.any?(0) ]).to eq([ nil, false, true ])
  end

  it "百分位數不在 50 到 95 每 5 一格裡時建立就失敗" do
    expect { planned(percentile: 83) }.to raise_error(ArgumentError, /83/)
  end
end
