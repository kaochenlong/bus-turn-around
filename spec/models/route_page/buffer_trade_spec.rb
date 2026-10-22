require "rails_helper"

RSpec.describe RoutePage::BufferTrade, type: :model do
  # A stored day with the given trips as [vehicle, ...] and layovers as
  # ["HH:MM" end time, minutes].
  def route_day(day, vehicles: [], layovers: [])
    RouteDay.create!(route_id: 9001, day:, route_name: "測試幹線", departure: "甲站", destination: "戊站",
                     static_day: day, loaded_at: Time.current).tap do |route_day|
      vehicles.each_with_index { |bus_id, index| add_trip(route_day, bus_id, Time.zone.parse("#{day} 06:00") + index.hours) }
      layovers.each { |time, minutes| add_layover(route_day, Time.zone.parse("#{day} #{time}"), minutes) }
    end
  end

  def add_trip(route_day, bus_id, start_time)
    route_day.trips.create!(bus_id:, path_attribute_id: 9001, go_back: 0, band: "other", start_time:, end_time: start_time + 50.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  def add_layover(route_day, end_time, minutes)
    route_day.layovers.create!(bus_id: "TEST-0001", go_back: 0, end_time:, next_start_time: end_time + minutes.minutes)
  end

  def trade(*days, minutes: 15) = described_class.new(RouteDay.where(id: days.map(&:id)), minutes:)

  # Day one: layovers ending 08:00 (5 min), 08:20 (20), 09:10 (2); day two: 08:30 (10).
  def four_layovers
    trade(route_day(Date.new(2026, 10, 19), layovers: [ [ "08:00", 5 ], [ "08:20", 20 ], [ "09:10", 2 ] ]),
          route_day(Date.new(2026, 10, 20), layovers: [ [ "08:30", 10 ] ]))
  end

  it "報涵蓋天數、量到的折返停留、趟次與每天平均車數" do
    trade = trade(route_day(Date.new(2026, 10, 19), vehicles: %w[A A B A B], layovers: [ [ "08:00", 1 ], [ "09:00", 1 ], [ "10:00", 1 ] ]),
                  route_day(Date.new(2026, 10, 20), vehicles: %w[A B C], layovers: [ [ "08:00", 1 ] ]))
    expect([ trade.n_days, trade.n_layovers, trade.n_trips, trade.vehicles_per_day ]).to eq([ 2, 4, 8, 2.5 ])
  end

  it "休息達成率是不少於緩衝分鐘數的比例" do
    expect(four_layovers.achieved_share).to eq(0.25)
  end

  it "車時下限只算不足的分鐘、上限每次都加滿，都是每天平均" do
    expect(four_layovers.vehicle_hours).to eq(described_class::Bound.new(lower: 0.2, upper: 0.5))
  end

  it "下限與上限各自報最忙的小時與那個小時平均多幾台車" do
    peak = four_layovers.peak
    expect([ peak.lower, peak.upper ]).to eq([ described_class::Peak.new(hour: 8, vehicles: 0.1), described_class::Peak.new(hour: 8, vehicles: 0.4) ])
  end

  it "兩個小時一樣忙時報較早的那個" do
    trade = trade(route_day(Date.new(2026, 10, 19), layovers: [ [ "07:30", 5 ], [ "08:30", 5 ] ]))
    expect(trade.peak.lower).to eq(described_class::Peak.new(hour: 7, vehicles: 0.2))
  end

  it "沒有折返停留時不報達成率、車時與車數" do
    trade = trade(route_day(Date.new(2026, 10, 19), vehicles: %w[A]))
    expect([ trade.n_layovers, trade.achieved_share, trade.vehicle_hours, trade.peak ]).to eq([ 0, nil, nil, nil ])
  end

  it "記得用的緩衝分鐘數" do
    expect(trade(route_day(Date.new(2026, 10, 19)), minutes: 10).minutes).to eq(10)
  end

  describe ".minutes" do
    it "沒給緩衝分鐘數時是 15" do
      expect([ described_class.minutes(nil), described_class.minutes("") ]).to eq([ 15, 15 ])
    end

    it "0 與 20 都接受" do
      expect([ described_class.minutes("0"), described_class.minutes("20") ]).to eq([ 0, 20 ])
    end

    %w[21 -1 abc 1.5].each do |value|
      it "#{value} 是頁面不接受的參數" do
        expect { described_class.minutes(value) }.to raise_error(RoutePage::Coverage::InvalidParameter)
      end
    end
  end
end
