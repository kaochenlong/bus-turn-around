require "rails_helper"

RSpec.describe RoutePage::BufferTrade, type: :model do
  # A stored day with the given trips as [vehicle, ...] and layovers as
  # ["HH:MM" end time, minutes, direction of the ending trip], the direction
  # 0 when left out.
  def route_day(day, vehicles: [], layovers: [])
    create(:route_day, day:).tap do |route_day|
      vehicles.each_with_index { |bus_id, index| add_trip(route_day, bus_id, Time.zone.parse("#{day} 06:00") + index.hours) }
      layovers.each { |time, minutes, go_back = 0| add_layover(route_day, Time.zone.parse("#{day} #{time}"), minutes, go_back) }
    end
  end

  def add_trip(route_day, bus_id, start_time)
    route_day.trips.create!(bus_id:, path_attribute_id: 9001, go_back: 0, band: "other", start_time:, end_time: start_time + 50.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  def add_layover(route_day, end_time, minutes, go_back)
    route_day.layovers.create!(bus_id: "TEST-0001", go_back:, end_time:, next_start_time: end_time + minutes.minutes)
  end

  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  # The lateness, hours and end, when given, go to the estimate as they are.
  def trade(*days, minutes: 15, ends: route_ends("stop", "stop"), **options)
    described_class.new(RouteDay.where(id: days.map(&:id)), minutes:, ends:, **options)
  end

  # Day one: layovers ending 08:00 (5 min), 08:20 (20), 09:10 (2); day two: 08:30 (10).
  def four_layovers(minutes: 15, **options)
    trade(route_day(Date.new(2026, 10, 19), layovers: [ [ "08:00", 5 ], [ "08:20", 20 ], [ "09:10", 2 ] ]),
          route_day(Date.new(2026, 10, 20), layovers: [ [ "08:30", 10 ] ]), minutes:, **options)
  end

  it "報涵蓋天數、停車端與直接折返那一端量到的折返停留、趟次與每天平均車數" do
    trade = trade(route_day(Date.new(2026, 10, 19), vehicles: %w[A A B A B], layovers: [ [ "08:00", 1 ], [ "09:00", 1 ], [ "10:00", 1 ] ]),
                  route_day(Date.new(2026, 10, 20), vehicles: %w[A B C], layovers: [ [ "08:00", 1 ] ]))
    expect([ trade.n_days, trade.n_layovers, trade.n_pass_through_layovers, trade.n_trips, trade.vehicles_per_day ]).to eq([ 2, 4, 0, 8, 2.5 ])
  end

  it "直接折返那一端的折返停留不進試算的基礎，另外報筆數" do
    day = route_day(Date.new(2026, 10, 19), layovers: [ [ "08:00", 2, 0 ], [ "09:00", 2, 0 ], [ "10:00", 2, 0 ], [ "11:00", 20, 1 ] ])
    trade = trade(day, ends: route_ends("pass_through", "stop"))
    expect([ trade.n_layovers, trade.n_pass_through_layovers ]).to eq([ 1, 3 ])
  end

  it "休息達成率是不少於緩衝分鐘數的比例" do
    expect(four_layovers.achieved_share).to eq(0.25)
  end

  it "休息達成率只看停車端：停車端 20 與 10 分鐘、直接折返那一端三次 2 分鐘，是 50%" do
    day = route_day(Date.new(2026, 10, 19), layovers: [ [ "08:00", 20, 1 ], [ "09:00", 10, 1 ], [ "10:00", 2, 0 ], [ "10:10", 2, 0 ], [ "10:20", 2, 0 ] ])
    expect(trade(day, ends: route_ends("pass_through", "stop")).achieved_share).to eq(0.5)
  end

  it "車時下限只算不足的分鐘、上限每次都加滿，都是每天平均" do
    expect(four_layovers.vehicle_hours).to eq(described_class::Bound.new(lower: 0.2, upper: 0.5))
  end

  it "直接折返那一端的折返停留不加車時：停車端 5 與 20 分鐘、那一端 2 與 1 分鐘，下限 0.2、上限 0.5" do
    day = route_day(Date.new(2026, 10, 19), layovers: [ [ "08:00", 5, 1 ], [ "08:20", 20, 1 ], [ "09:00", 2, 0 ], [ "09:10", 1, 0 ] ])
    expect(trade(day, ends: route_ends("pass_through", "stop")).vehicle_hours).to eq(described_class::Bound.new(lower: 0.2, upper: 0.5))
  end

  it "下限與上限各自報最忙的小時與那個小時平均多幾台車" do
    peak = four_layovers.peak
    expect([ peak.lower, peak.upper ]).to eq([ described_class::Peak.new(hour: 8, vehicles: 0.1), described_class::Peak.new(hour: 8, vehicles: 0.4) ])
  end

  it "兩個小時一樣忙時報較早的那個" do
    trade = trade(route_day(Date.new(2026, 10, 19), layovers: [ [ "07:30", 5 ], [ "08:30", 5 ] ]))
    expect(trade.peak.lower).to eq(described_class::Peak.new(hour: 7, vehicles: 0.2))
  end

  it "最忙的小時不看直接折返那一端：17 點那一端的三次不算，下限與上限都報 8 點" do
    day = route_day(Date.new(2026, 10, 19), layovers: [ [ "08:10", 3, 1 ], [ "08:40", 9, 1 ], [ "17:10", 2, 0 ], [ "17:20", 2, 0 ], [ "17:30", 2, 0 ] ])
    peak = trade(day, ends: route_ends("pass_through", "stop")).peak
    expect([ peak.lower, peak.upper ]).to eq([ described_class::Peak.new(hour: 8, vehicles: 0.3), described_class::Peak.new(hour: 8, vehicles: 0.5) ])
  end

  it "沒有折返停留時不報達成率、車時與車數" do
    trade = trade(route_day(Date.new(2026, 10, 19), vehicles: %w[A]))
    expect([ trade.n_layovers, trade.achieved_share, trade.vehicle_hours, trade.peak ]).to eq([ 0, nil, nil, nil ])
  end

  it "只有直接折返那一端有折返停留時，不報達成率、車時與車數，照報那一端的 3 次" do
    day = route_day(Date.new(2026, 10, 19), layovers: [ [ "08:00", 2, 0 ], [ "08:10", 2, 0 ], [ "08:20", 2, 0 ] ])
    trade = trade(day, ends: route_ends("pass_through", "stop"))
    expect([ trade.achieved_share, trade.vehicle_hours, trade.peak, trade.n_pass_through_layovers ]).to eq([ nil, nil, nil, 3 ])
  end

  it "兩端都直接折返時，試算的基礎是 0 筆，兩個方向的折返停留都報成直接折返" do
    day = route_day(Date.new(2026, 10, 19), layovers: [ [ "08:00", 2, 0 ], [ "09:00", 2, 1 ] ])
    trade = trade(day, ends: route_ends("pass_through", "pass_through"))
    expect([ trade.n_layovers, trade.achieved_share, trade.vehicle_hours, trade.peak, trade.n_pass_through_layovers ]).to eq([ 0, nil, nil, nil, 2 ])
  end

  it "記得用的緩衝分鐘數" do
    expect(trade(route_day(Date.new(2026, 10, 19)), minutes: 10).minutes).to eq(10)
  end

  describe "晚到" do
    it "休息 15、晚到 6 時每次折返要留 21 分鐘" do
      trade = four_layovers(late: 6)
      expect([ trade.minutes, trade.late, trade.hold ]).to eq([ 15, 6, 21 ])
    end

    it "四次停留在休息 15、晚到 6 時，車時用 21 分鐘算：下限 0.4、上限 0.7" do
      expect(four_layovers(late: 6).vehicle_hours).to eq(described_class::Bound.new(lower: 0.4, upper: 0.7))
    end

    it "四次停留在休息 15、晚到 6 時，最忙的都是 8 點：下限 0.2、上限 0.5 台" do
      peak = four_layovers(late: 6).peak
      expect([ peak.lower, peak.upper ]).to eq([ described_class::Peak.new(hour: 8, vehicles: 0.2), described_class::Peak.new(hour: 8, vehicles: 0.5) ])
    end

    it "現在的達成率照休息 15 算是 25%，車數不變、再晚到 6 分鐘還停得到 15 分鐘的是 0%" do
      trade = four_layovers(late: 6)
      expect([ trade.achieved_share, trade.achieved_share_late ]).to eq([ 0.25, 0.0 ])
    end

    it "休息 21、晚到 0 的車時跟休息 15、晚到 6 一樣，但現在的達成率是 0%" do
      trade = four_layovers(minutes: 21)
      expect([ trade.vehicle_hours, trade.achieved_share ]).to eq([ described_class::Bound.new(lower: 0.4, upper: 0.7), 0.0 ])
    end

    it "晚到比停留長時下限加得比休息多：六次 2 分鐘的停留在休息 15、晚到 6 時，下限 1.9（每次 19 分鐘）、上限 2.1（每次 21 分鐘）" do
      day = route_day(Date.new(2026, 10, 19), layovers: %w[08:00 08:10 08:20 08:30 08:40 08:50].map { [ it, 2 ] })
      expect(trade(day, late: 6).vehicle_hours).to eq(described_class::Bound.new(lower: 1.9, upper: 2.1))
    end
  end

  describe "曲線" do
    def bound(lower, upper) = described_class::Bound.new(lower:, upper:)

    it "有 41 點，第 h 點的要留分鐘數就是 h" do
      curve = four_layovers.curve
      expect([ curve.size, curve.map(&:hold) ]).to eq([ 41, (0..40).to_a ])
    end

    it "要留 0 分鐘那一點：車時都是 0.0，停得到的比例是 100%" do
      point = four_layovers.curve.first
      expect([ point.vehicle_hours, point.achieved_share ]).to eq([ bound(0.0, 0.0), 1.0 ])
    end

    it "一天十二次停留（六次 10 分鐘、六次 30 分鐘）在要留 15 分鐘時，再多留 1 分鐘下限多 0.1、上限多 0.2" do
      day = route_day(Date.new(2026, 10, 19), layovers: (8..19).map { [ format("%02d:00", it), it.even? ? 10 : 30 ] })
      expect(trade(day).next_minute).to eq(bound(0.1, 0.2))
    end

    it "四次停留在休息 15 時，逐小時是 8 點 0.1／0.4、9 點 0.1／0.1" do
      hours = [ described_class::Hour.new(hour: 8, lower: 0.1, upper: 0.4), described_class::Hour.new(hour: 9, lower: 0.1, upper: 0.1) ]
      expect(four_layovers.point.hourly).to eq(hours)
    end

    it "休息 15、晚到 6 時，報出的車時是第 21 點的 0.4 與 0.7，現在的達成率是第 15 點的 25%" do
      trade = four_layovers(late: 6)
      expect([ trade.curve[21].vehicle_hours, trade.vehicle_hours, trade.curve[15].achieved_share, trade.achieved_share ]).to eq([ bound(0.4, 0.7), bound(0.4, 0.7), 0.25, 0.25 ])
    end

    it "每一點另外帶沒有四捨五入的車時，給圖的座標用：四次停留要留 21 分鐘時是 47 與 84 分鐘除以 2 天、再除以 60" do
      exact = four_layovers.curve[21].exact
      expect([ exact.lower, exact.upper ]).to match([ be_within(1e-9).of(47 / 120.0), be_within(1e-9).of(84 / 120.0) ])
    end

    it "沒有折返停留時沒有曲線，也沒有再多留 1 分鐘的成本" do
      trade = trade(route_day(Date.new(2026, 10, 19), vehicles: %w[A]))
      expect([ trade.curve, trade.point, trade.next_minute ]).to eq([ nil, nil, nil ])
    end
  end

  describe "套用的小時與加在哪一端" do
    def bound(lower, upper) = described_class::Bound.new(lower:, upper:)

    it "沒選小時與端點時不算篩選，選了就算" do
      day = route_day(Date.new(2026, 10, 19))
      expect([ {}, { hour_range: 9...10 }, { end_go_back: 1 } ].map { trade(day, **it).filtered? }).to eq([ false, true, true ])
    end

    it "只看 9 點到 10 點時，試算的基礎是 1 筆，全天照報 4 筆" do
      trade = four_layovers(hour_range: 9...10)
      expect([ trade.n_layovers, trade.n_stopping_layovers ]).to eq([ 1, 4 ])
    end

    it "只看 9 點到 10 點時，車時 0.1 與 0.1、達成率 0%、最忙的都是 9 點" do
      trade = four_layovers(hour_range: 9...10)
      expect([ trade.vehicle_hours, trade.achieved_share, trade.peak.lower.hour, trade.peak.upper.hour ]).to eq([ bound(0.1, 0.1), 0.0, 9, 9 ])
    end

    it "只看 12 點到 13 點時沒有折返停留：不報任何數字，全天照報 4 筆" do
      trade = four_layovers(hour_range: 12...13)
      expect([ trade.n_layovers, trade.n_stopping_layovers, trade.curve, trade.vehicle_hours, trade.achieved_share ]).to eq([ 0, 4, nil, nil, nil ])
    end

    it "兩端都停車、只選方向 1 時，基礎是 2 筆，車時 0.2 與 0.5、達成率 50%" do
      trade = trade(route_day(Date.new(2026, 10, 19), layovers: [ [ "08:00", 5, 0 ], [ "08:20", 20, 1 ], [ "09:10", 2, 1 ] ]), end_go_back: 1)
      expect([ trade.n_layovers, trade.vehicle_hours, trade.achieved_share ]).to eq([ 2, bound(0.2, 0.5), 0.5 ])
    end

    it "方向 0 直接折返時選方向 1，數字跟沒選一樣：2 筆、0.2 與 0.5、50%" do
      day = route_day(Date.new(2026, 10, 19), layovers: [ [ "08:00", 5, 1 ], [ "08:20", 20, 1 ], [ "09:00", 2, 0 ] ])
      trades = [ 1, nil ].map { trade(day, ends: route_ends("pass_through", "stop"), end_go_back: it) }
      expect(trades.map { [ it.n_layovers, it.vehicle_hours, it.achieved_share ] }).to eq([ [ 2, bound(0.2, 0.5), 0.5 ] ] * 2)
    end

    it "端點的名稱取涵蓋日子裡最新一天、頁面路線自己的站序：成員路線的站序號碼較大也不算，方向 1 是乙站" do
      first, latest = route_day(Date.new(2026, 10, 19)), route_day(Date.new(2026, 10, 20))
      first.stops.create!(go_back: 1, seq: 9, stop_name: "甲站")
      latest.stops.create!([ { go_back: 1, seq: 9, stop_name: "乙站" }, { go_back: 1, seq: 12, stop_name: "丙站", route_id: 9050 } ])
      expect(trade(first, latest).stopping_end_names[1]).to eq("乙站")
    end
  end

  describe ".hour_range" do
    it "沒給時是全天" do
      expect([ described_class.hour_range(nil, nil), described_class.hour_range("", "") ]).to eq([ 0...24, 0...24 ])
    end

    it "只給開始小時時，結束是 24" do
      expect([ described_class.hour_range("9", nil), described_class.hour_range("0", "1") ]).to eq([ 9...24, 0...1 ])
    end

    [ %w[10 9], %w[24 24], %w[0 0], %w[0 25], %w[abc 24], [ [ "1" ], "24" ] ].each do |first, last|
      it "#{first.inspect} 點到 #{last.inspect} 點是頁面不接受的參數" do
        expect { described_class.hour_range(first, last) }.to raise_error(RoutePage::Coverage::InvalidParameter)
      end
    end
  end

  describe ".end_go_back" do
    it "沒給時是所有停車端" do
      expect([ nil, "" ].map { described_class.end_go_back(it, ends: route_ends("stop", "stop")) }).to eq([ nil, nil ])
    end

    it "兩端都停車時 0 與 1 都接受" do
      expect(%w[0 1].map { described_class.end_go_back(it, ends: route_ends("stop", "stop")) }).to eq([ 0, 1 ])
    end

    [ "0", "2", "x", [ "1" ] ].each do |value|
      it "方向 0 直接折返時，#{value.inspect} 是頁面不接受的參數" do
        expect { described_class.end_go_back(value, ends: route_ends("pass_through", "stop")) }.to raise_error(RoutePage::Coverage::InvalidParameter)
      end
    end
  end

  describe ".late" do
    it "沒給晚到分鐘數時是 0" do
      expect([ described_class.late(nil), described_class.late("") ]).to eq([ 0, 0 ])
    end

    it "0 與 20 都接受" do
      expect([ described_class.late("0"), described_class.late("20") ]).to eq([ 0, 20 ])
    end

    [ "21", "-1", "abc", "1.5", [ "1" ] ].each do |value|
      it "#{value.inspect} 是頁面不接受的參數" do
        expect { described_class.late(value) }.to raise_error(RoutePage::Coverage::InvalidParameter)
      end
    end
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
