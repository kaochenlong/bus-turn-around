require "rails_helper"

RSpec.describe RoutePage::SlowLegs, type: :model do
  def cell(kmh, n_trips: 20, small_sample: false) = RoutePage::StopSpeeds::Cell.new(kmh:, n_trips:, small_sample:, level: 1)

  def leg(name, meters, cells) = RoutePage::StopSpeeds::Leg.new(seq: 0, from_name: "#{name}甲", to_name: "#{name}乙", meters:, cells:)

  # Stands in for RoutePage::StopSpeeds with one direction holding the legs.
  def slow_legs(*legs, go_back: 0)
    direction = RoutePage::StopSpeeds::Direction.new(go_back:, legs:, level_ranges: [])
    described_class.new(instance_double(RoutePage::StopSpeeds, directions: [ direction ]))
  end

  def speeds(legs) = legs.rows.map(&:kmh)

  it "五段尖峰在 200 公尺以上、一段 150 公尺更慢：列最慢的四段，照時速排，不列 150 公尺那段" do
    legs = [ 5.8, 5.6, 4.2, 5.5, 4.9 ].each_with_index.map { |kmh, index| leg("L#{index}", 300.0, { "morning_peak" => cell(kmh) }) }
    legs << leg("short", 150.0, { "morning_peak" => cell(3.0) })
    expect(speeds(slow_legs(*legs))).to eq([ 4.2, 4.9, 5.5, 5.6 ])
  end

  it "剛好 200 公尺算" do
    expect(speeds(slow_legs(leg("A", 200.0, { "evening_peak" => cell(5.0) })))).to eq([ 5.0 ])
  end

  it "日間與其餘時段不算" do
    expect(speeds(slow_legs(leg("A", 300.0, { "daytime" => cell(2.0), "other" => cell(1.0), "evening_peak" => cell(5.0) })))).to eq([ 5.0 ])
  end

  it "樣本少的不算" do
    expect(speeds(slow_legs(leg("A", 300.0, { "morning_peak" => cell(2.0, n_trips: 3, small_sample: true) })))).to eq([])
  end

  it "沒有資料的格子不算" do
    empty = RoutePage::StopSpeeds::Cell.new(kmh: nil, n_trips: 0, small_sample: false, level: nil)
    expect(speeds(slow_legs(leg("A", 300.0, { "morning_peak" => empty })))).to eq([])
  end

  it "一列寫方向、兩站、時段、距離、趟數與時速" do
    row = slow_legs(leg("A", 320.4, { "morning_peak" => cell(4.2, n_trips: 18) }), go_back: 1).rows.sole
    expect(row.to_h).to eq(go_back: 1, from_name: "A甲", to_name: "A乙", band: "morning_peak", meters: 320.4, n_trips: 18, kmh: 4.2)
  end

  it "同一段早晚尖峰各算一段" do
    expect(speeds(slow_legs(leg("A", 300.0, { "morning_peak" => cell(4.0), "evening_peak" => cell(5.0) })))).to eq([ 4.0, 5.0 ])
  end
end
