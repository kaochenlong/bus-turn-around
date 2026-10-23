require "rails_helper"

RSpec.describe RoutePage::MrtOverlap, type: :model do
  # A stored day whose direction 0 stops, at sequence 0 onward, have the given
  # nearest-entrance distances.
  def route_day(distances)
    create(:route_day, mrt_exits_day: Date.new(2026, 10, 19)).tap do |route_day|
      distances.each_with_index do |meters, seq|
        route_day.stops.create!(go_back: 0, seq:, stop_name: "站#{seq}", nearest_exit_name: "出口", nearest_exit_meters: meters)
      end
    end
  end

  def overlap(route_day) = described_class.new(RouteDay.where(id: route_day.id))

  # A morning-peak trip in direction 0 with the given counts by sequence number.
  def trip_with_counts(route_day, start, counts)
    start_time = Time.zone.parse("2026-10-19 #{start}")
    trip = route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back: 0, band: "morning_peak", start_time:,
                                   end_time: start_time + 50.minutes, first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5,
                                   completeness: "complete", start_from_arrival: false, end_from_departure: false)
    counts.each { |seq, on_board| trip.trip_stop_counts.create!(seq:, on_board:) }
  end

  it "去程五站 900、400、250、450、700 公尺：重疊度 300 公尺 20%、500 公尺 60%、800 公尺 80%" do
    direction = overlap(route_day([ 900, 400, 250, 450, 700 ])).directions.sole
    expect([ direction.go_back, direction.n_stops, direction.shares ]).to eq([ 0, 5, { 300 => 0.2, 500 => 0.6, 800 => 0.8 } ])
  end

  it "500 公尺下唯一的重疊路段是第 1 到 3 站，帶起訖站名與站數" do
    stretch = overlap(route_day([ 900, 400, 250, 450, 700 ])).stretches.sole
    expect(stretch.to_h.except(:loads)).to eq(go_back: 0, first_seq: 1, last_seq: 3, first_stop: "站1", last_stop: "站3", n_stops: 3)
  end

  it "只有第 4 站在 500 公尺內：沒有重疊路段，重疊度仍大於 0" do
    result = overlap(route_day([ 900, 900, 900, 900, 400 ]))
    expect([ result.stretches, result.directions.sole.shares[500] ]).to eq([ [], 0.2 ])
  end

  it "路段內每趟每站的車上人數合在一起算：10、20 與 30 得 2 趟、中位數 20.0、p90 28.0" do
    day = route_day([ 900, 400, 250, 900 ])
    trip_with_counts(day, "07:00", 1 => 10, 2 => 20).then { trip_with_counts(day, "07:30", 1 => 30, 3 => 99) }
    expect(overlap(day).stretches.sole.loads).to eq([ { band: "morning_peak", n_trips: 2, median: 20.0, p90: 28.0 } ])
  end

  it "重疊路段的站序範圍：第 2 到 4 站" do
    expect(overlap(route_day([ 900, 900, 400, 250, 450 ])).stretch_ranges).to eq(0 => [ 2..4 ])
  end

  it "站牌沒有距離時沒有重疊路段的站序範圍" do
    expect(overlap(route_day([ nil, nil ])).stretch_ranges).to eq({})
  end

  it "站牌沒有距離（之前寫入的資料）時標成需要重算" do
    expect(overlap(route_day([ nil, nil ])).needs_reload?).to be(true)
  end

  it "帶出算的時候用的出入口快照日" do
    expect(overlap(route_day([ 400 ])).mrt_exits_day).to eq(Date.new(2026, 10, 19))
  end
end
