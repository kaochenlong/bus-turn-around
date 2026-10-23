require "rails_helper"

RSpec.describe RoutePage::RunTimes, type: :model do
  let(:route_day) do
    create(:route_day)
  end

  # A trip starting at `start` (Taipei time on 2026-10-19 unless a date is
  # given) that runs for `minutes`; other attributes default to a complete trip.
  def trip(start, minutes, go_back: 0, **attributes)
    start_time = Time.zone.parse(start.include?("-") ? start : "2026-10-19 #{start}")
    route_day.trips.create!({ bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:,
                              end_time: start_time + minutes.minutes, first_seq: 0, last_seq: 4, n_events: 10,
                              n_stops_observed: 5, completeness: "complete", start_from_arrival: false,
                              end_from_departure: false }.merge(attributes))
  end

  def run_times = described_class.new(RouteDay.where(id: route_day.id))

  def row(go_back, hour) = run_times.rows.find { it.go_back == go_back && it.hour == hour }

  it "只算完整趟次；起點用到站時刻的排除並計數，不完整的趟次不算也不計排除" do
    trip("07:00", 50).then { trip("07:10", 52) }
    trip("07:20", 60, start_from_arrival: true).then { trip("07:30", 40, completeness: "missing_end") }
    expect([ row(0, 7).n_trips, run_times.excluded.fetch(0) ]).to eq([ 2, 1 ])
  end

  it "終點用離站時刻的趟次也排除" do
    trip("08:00", 50, end_from_departure: true)
    expect([ row(0, 8), run_times.excluded.fetch(0) ]).to eq([ nil, 1 ])
  end

  it "07 時五趟 50、52、55、60、70 分鐘：5 趟、p50 55.0、p85 64.0、p95 68.0，不算樣本少" do
    [ 50, 52, 55, 60, 70 ].each_with_index { |minutes, index| trip(format("07:%02d", index * 10), minutes) }
    expect([ row(0, 7).n_trips, row(0, 7).percentiles, row(0, 7).small_sample ]).to eq([ 5, [ 55.0, 64.0, 68.0 ], false ])
  end

  it "返程 22 時只有兩趟：標成樣本少，百分位數照樣有" do
    trip("22:00", 40, go_back: 1).then { trip("22:30", 50, go_back: 1) }
    expect([ row(1, 22).small_sample, row(1, 22).percentiles ]).to eq([ true, [ 45.0, 48.5, 49.5 ] ])
  end

  it "23:40 發車、隔天 00:50 到站：算在 23 時，行駛時間 70.0 分鐘" do
    trip("2026-10-19 23:40", 70)
    expect([ row(0, 23).n_trips, row(0, 23).percentiles.first ]).to eq([ 1, 70.0 ])
  end

  it "沒有排除趟次的方向，排除數是 0" do
    trip("07:00", 50)
    expect(run_times.excluded.fetch(1)).to eq(0)
  end
end
