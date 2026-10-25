require "rails_helper"

RSpec.describe RoutePage::TimetableOverruns, type: :model do
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

  def rows(buffer: 15) = described_class.new(RouteDay.where(id: route_day.id), buffer:).rows

  def row(percentile, buffer: 15) = rows(buffer:).find { it.percentile == percentile }

  it "每個百分位數一列：50 到 95 每 5 一格共十列" do
    five_trips
    expect(rows.map(&:percentile)).to eq([ 50, 55, 60, 65, 70, 75, 80, 85, 90, 95 ])
  end

  # The spec's example "Rows for those trips", shares as fractions.
  [ [ 50, 0.4, 0.0, 6.0 ], [ 85, 0.2, 0.0, 5.0 ], [ 95, 0.2, 0.0, 2.0 ] ].each do |percentile, overrun_share, exhausted_share, median|
    it "06 時五趟 44、47、50、52、60、休息 15：q#{percentile} 超時比例 #{overrun_share}、吃光休息 #{exhausted_share}、超時中位數 #{median}" do
      five_trips
      expect(row(percentile).to_h.except(:percentile)).to eq(overrun_share:, exhausted_share:, median_overrun: median)
    end
  end

  it "休息 5 分鐘時，q50 的兩趟超時 2 與 10 裡 10 吃光休息：比例 0.2" do
    five_trips
    expect(row(50, buffer: 5).exhausted_share).to eq(0.2)
  end

  it "休息 0 分鐘時，超過一分鐘就算吃光：吃光的比例等於超時的比例" do
    five_trips
    expect(row(50, buffer: 0).to_h.values_at(:overrun_share, :exhausted_share)).to eq([ 0.4, 0.4 ])
  end

  it "五趟都是 50 分鐘時沒有一趟超時：比例 0.0、中位數 nil" do
    5.times { trip(format("06:%02d", it * 10), 50) }
    expect(row(50).to_h.except(:percentile)).to eq(overrun_share: 0.0, exhausted_share: 0.0, median_overrun: nil)
  end

  it "樣本少的小時用全天的計畫值：返程 22 時兩趟 30 與 70 用全天七趟的 p95 67，70 超時 3；07 時的 60 超時 2，中位數 2.5" do
    [ 44, 47, 50, 52, 60 ].each_with_index { |minutes, index| trip(format("07:%02d", index * 10), minutes, go_back: 1) }
    trip("22:00", 30, go_back: 1).then { trip("22:30", 70, go_back: 1) }
    expect(row(95).median_overrun).to eq(2.5)
  end

  it "不完整、起點用到站時刻、終點用離站時刻的趟次不在分母：加了三趟 100 分鐘，q50 的超時比例仍是 0.4" do
    five_trips
    trip("06:50", 100, start_from_arrival: true).then { trip("06:55", 100, end_from_departure: true) }
    trip("06:57", 100, completeness: "missing_end")
    expect(row(50).overrun_share).to eq(0.4)
  end

  it "沒有任何行駛時間時，每一列的兩個比例與中位數都是 nil" do
    expect(rows.map { [ it.overrun_share, it.exhausted_share, it.median_overrun ] }.uniq).to eq([ [ nil, nil, nil ] ])
  end
end
