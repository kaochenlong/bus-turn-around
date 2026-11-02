require "rails_helper"

# The sentences are built from the month card's query objects, so these examples
# stand in for them with exactly the figures each rule reads.
RSpec.describe RoutePage::MonthFindings, type: :model do
  def layover_row(go_back: 1, stop_name: "甲站", short_share: 0.43)
    RoutePage::LayoverStats::Row.new(go_back:, stop_name:, n_layovers: 100, percentiles: [ 5.0, 15.0, 30.0 ], short_share:)
  end

  def hour_row(hour, n_layovers, percent) = RoutePage::LayoverHours::Row.new(hour:, n_layovers:, short_share: percent / 100.0)

  def cycle_row(hour, round_trip_p50, cycle_p10, n_round_trips: 5, n_cycles: 5)
    RoutePage::Cycles::Row.new(hour:, n_round_trips:, round_trip_percentiles: [ round_trip_p50, nil ], n_cycles:, cycle_percentiles: [ cycle_p10, nil ])
  end

  def rule(n_windows: 100, n_flagged: 51, n_over_daily: 16)
    RoutePage::RestWindows::Rule.new(rule: :four_hours, n_windows:, n_flagged:, flagged_share: n_windows.zero? ? nil : n_flagged.fdiv(n_windows), day_low: nil, day_high: nil,
                                     n_over_daily:, n_flagged_over_daily: 0)
  end

  def period(from, to, low, high, on_road:, needed_low: 12, needed_high: 18)
    RoutePage::ScheduleComparison::Period.new(start_minute: from * 60, end_minute: to * 60, low_minutes: low, high_minutes: high, per_hour_low: 0.0, per_hour_high: 0.0,
                                              departures_per_hour: { 0 => 0.0, 1 => 0.0 }, on_road:, needed_low:, needed_high:)
  end

  def others(departures, trips_per_day) = RoutePage::ScheduleComparison::Others.new(departures:, trips_per_day:, on_road: 0.0)

  def version(periods: [], others: nil) = RoutePage::ScheduleComparison::Version.new(days: [], periods:, others:)

  # A month card whose weekdays have these figures. It answers peak_periods from
  # the newest version the way MonthCard does.
  def month_card(stats: [ layover_row ], hours: {}, cycle_rows: [], four_hours: rule(n_windows: 0, n_flagged: 0, n_over_daily: 0), versions: [])
    lowest = versions.last&.periods.to_a.map(&:low_minutes).min
    instance_double(RoutePage::MonthCard, stop_go_backs: stats.map(&:go_back), layover_stats: instance_double(RoutePage::LayoverStats, rows: stats),
                                          layover_hours: instance_double(RoutePage::LayoverHours).tap { |double| allow(double).to receive(:rows) { hours.fetch(it, []) } },
                                          cycles: instance_double(RoutePage::Cycles, rows: cycle_rows), rest_windows: instance_double(RoutePage::RestWindows, rule: four_hours),
                                          schedule: instance_double(RoutePage::ScheduleComparison, versions:), peak_periods: versions.last&.periods.to_a.select { it.low_minutes == lowest })
  end

  def sentences(**figures) = described_class.new(month_card(**figures)).sentences

  describe "第一句：停車端的折返停留" do
    let(:hours) { { 1 => [ hour_row(8, 10, 80), hour_row(12, 20, 5), hour_row(17, 12, 83), hour_row(18, 16, 62), hour_row(19, 27, 78), hour_row(23, 6, 100) ] } }

    it "規格的例子：集中的小時併連續，再接比例最低的小時" do
      expect(sentences(hours:)).to eq([ "停車端的折返停留有 43% 不到 15 分鐘，集中在 08 時（80%）與 17 到 19 時（62% 到 83%）回來的車；12 時回來的車只有 5%。" ])
    end

    it "沒有小時達到 60%：只留比例與最低的小時" do
      expect(sentences(hours: { 1 => [ hour_row(8, 10, 59), hour_row(12, 20, 5) ] })).to eq([ "停車端的折返停留有 43% 不到 15 分鐘；12 時回來的車只有 5%。" ])
    end

    it "剛好 60% 算集中" do
      expect(sentences(hours: { 1 => [ hour_row(8, 10, 60), hour_row(12, 20, 5) ] }).first).to include("集中在 08 時（60%）回來的車")
    end

    it "筆數不到 10 的小時不算集中，也不算最低" do
      expect(sentences(hours: { 1 => [ hour_row(8, 9, 90), hour_row(12, 9, 1) ] })).to eq([ "停車端的折返停留有 43% 不到 15 分鐘。" ])
    end

    it "最低的小時本身就在集中的小時裡：不接「只有」那一段，免得前後矛盾" do
      expect(sentences(hours: { 1 => [ hour_row(8, 10, 80) ] })).to eq([ "停車端的折返停留有 43% 不到 15 分鐘，集中在 08 時（80%）回來的車。" ])
    end

    it "三段集中的小時：前面用頓號，最後一段用與" do
      rows = [ hour_row(6, 10, 70), hour_row(9, 10, 70), hour_row(11, 10, 70), hour_row(12, 10, 5) ]
      expect(sentences(hours: { 1 => rows }).first).to include("集中在 06 時（70%）、09 時（70%）與 11 時（70%）回來的車")
    end

    it "連續的小時比例都一樣：只寫一個比例" do
      expect(sentences(hours: { 1 => [ hour_row(8, 10, 70), hour_row(9, 10, 70) ] }).first).to include("08 到 09 時（70%）")
    end

    it "兩個停車端：各一句，句首寫末站名" do
      stats = [ layover_row(go_back: 0, stop_name: "莊敬里", short_share: 0.5), layover_row(go_back: 1, stop_name: "板橋前站", short_share: 0.3) ]
      expect(sentences(stats:)).to eq([ "莊敬里的折返停留有 50% 不到 15 分鐘。", "板橋前站的折返停留有 30% 不到 15 分鐘。" ])
    end

    it "直接折返那一端不寫" do
      stats = [ layover_row(go_back: 0, stop_name: "青年公園", short_share: 0.9), layover_row(go_back: 1) ]
      card = month_card(stats:)
      allow(card).to receive(:stop_go_backs).and_return([ 1 ])
      expect(described_class.new(card).sentences).to eq([ "停車端的折返停留有 43% 不到 15 分鐘。" ])
    end

    it "那一端沒有折返停留：這一句不出現" do
      expect(sentences(stats: [ layover_row(short_share: nil) ])).to eq([])
    end
  end

  describe "第二句：週期最緊的一成跟來回一趟差不到 4 分鐘的發車小時" do
    def tight_sentence(rows) = sentences(stats: [], cycle_rows: rows)

    it "併連續的小時" do
      rows = [ cycle_row(8, 150.0, 148.0), cycle_row(9, 150.0, 140.0), cycle_row(10, 150.0, 153.9), cycle_row(17, 150.0, 150.0), cycle_row(18, 150.0, 147.0), cycle_row(19, 150.0, 147.0) ]
      expect(tight_sentence(rows)).to eq([ "08、10、17 到 19 時發車的車，週期最緊的一成跟來回一趟的中位數差不到 4 分鐘，車回到停車端幾乎沒有多餘的時間。" ])
    end

    it "沒有這種小時：這一句不出現" do
      expect(tight_sentence([ cycle_row(8, 150.0, 140.0) ])).to eq([])
    end

    it "剛好差 4 分鐘不算" do
      expect(tight_sentence([ cycle_row(8, 150.0, 146.0) ])).to eq([])
    end

    it "來回一趟不到 5 筆不算" do
      expect(tight_sentence([ cycle_row(8, 150.0, 149.0, n_round_trips: 4) ])).to eq([])
    end

    it "週期不到 5 筆不算" do
      expect(tight_sentence([ cycle_row(8, 150.0, 149.0, n_cycles: 4) ])).to eq([])
    end
  end

  describe "第三句：連續 4 小時" do
    it "比例，以及落在當天行駛超過 10 小時的車上的比例" do
      expect(sentences(stats: [], four_hours: rule)).to eq([ "能判斷的連續 4 小時裡，有 51% 停留累計不到 30 分鐘。這是車的數字：其中 16% 的視窗落在當天行駛超過 10 小時的車上，這種車若守每日駕車 10 小時的規定就換過人。" ])
    end

    it "沒有視窗：這一句不出現" do
      expect(sentences(stats: [], four_hours: rule(n_windows: 0, n_flagged: 0, n_over_daily: 0))).to eq([])
    end
  end

  describe "第四句：公告對路上的車" do
    def schedule_sentence(periods) = sentences(stats: [], versions: [ version(periods:) ]).sole

    let(:peaks) { [ period(6.5, 8, 4, 6, on_road: 10.0, needed_low: 30, needed_high: 46), period(16, 17.5, 4, 6, on_road: 16.7, needed_low: 30, needed_high: 46) ] }
    let(:off_peaks) { [ period(8, 16, 10, 15, on_road: 13.6), period(17.5, 20, 10, 15, on_road: 15.7) ] }

    it "尖峰與其他時段：取下界最小的時段，路上的車取整數" do
      expect(schedule_sentence(peaks + off_peaks)).to eq("尖峰公告 4–6 分一班，照現在的週期要 30–46 台車，量到路上約 10 到 17 台。其他時段用同一個算法是 12–18 台，路上約 14 到 16 台。差距的原因公開資料看不出來。")
    end

    it "其他時段只取 08:00 起、20:00 之前開始的" do
      early_and_late = [ period(5.5, 6.5, 10, 15, on_road: 5.3, needed_low: 12, needed_high: 18), period(20, 21, 15, 20, on_road: 12.6, needed_low: 9, needed_high: 12) ]
      expect(schedule_sentence(peaks + off_peaks + early_and_late)).to include("其他時段用同一個算法是 12–18 台，路上約 14 到 16 台。")
    end

    it "20:00 開始的不算其他時段，08:00 開始的算" do
      expect(schedule_sentence([ peaks.first, period(8, 9, 10, 15, on_road: 13.0), period(20, 21, 15, 20, on_road: 99.0) ])).to include("路上約 13 台。")
    end

    it "沒有其他時段：不寫那一段" do
      expect(schedule_sentence(peaks)).to eq("尖峰公告 4–6 分一班，照現在的週期要 30–46 台車，量到路上約 10 到 17 台。差距的原因公開資料看不出來。")
    end

    it "尖峰只有一個時段：路上的車寫一個數" do
      expect(schedule_sentence([ peaks.first ])).to include("量到路上約 10 台。")
    end

    it "兩個尖峰上界不同：班距與要幾台都取整個範圍" do
      rows = [ period(6, 8, 4, 6, on_road: 10.0, needed_low: 30, needed_high: 46), period(16, 18, 4, 8, on_road: 10.2, needed_low: 23, needed_high: 46) ]
      expect(schedule_sentence(rows)).to start_with("尖峰公告 4–8 分一班，照現在的週期要 23–46 台車，量到路上約 10 台。")
    end

    it "上下界相同：只寫一個數" do
      expect(schedule_sentence([ period(6, 8, 30, 30, on_road: 3.0, needed_low: 6, needed_high: 6) ])).to start_with("尖峰公告 30 分一班，照現在的週期要 6 台車，")
    end

    it "沒有週期：不寫要幾台" do
      rows = [ period(6, 8, 4, 6, on_road: 10.0, needed_low: nil, needed_high: nil), period(8, 16, 10, 15, on_road: 14.0, needed_low: nil, needed_high: nil) ]
      expect(schedule_sentence(rows)).to eq("尖峰公告 4–6 分一班，量到路上約 10 台。其他時段路上約 14 台。差距的原因公開資料看不出來。")
    end

    it "公告改過：看最新的版本" do
      old = version(periods: [ period(6, 8, 8, 10, on_road: 1.0) ])
      expect(sentences(stats: [], versions: [ old, version(periods: [ peaks.first ]) ]).sole).to start_with("尖峰公告 4–6 分一班")
    end

    it "只有定時班次：規格的例子" do
      expect(sentences(stats: [], versions: [ version(others: others(Array.new(37) { it }, { 0 => 37.1, 1 => 37.1 })) ])).to eq([ "定時班次一天 37 班，量到每個方向約 37 趟。" ])
    end

    it "只有定時班次、兩個方向取整數後不同：分開寫" do
      expect(sentences(stats: [], versions: [ version(others: others(Array.new(37) { it }, { 0 => 37.1, 1 => 35.6 })) ])).to eq([ "定時班次一天 37 班，量到去程約 37 趟、返程約 36 趟。" ])
    end

    it "時段與定時班次都沒有：這一句不出現" do
      expect(sentences(stats: [], versions: [ version(others: others([], { 0 => 3.0, 1 => 3.0 })) ])).to eq([])
    end

    it "沒有平日：這一句不出現" do
      expect(sentences(stats: [], versions: [])).to eq([])
    end
  end

  it "四句的順序是折返停留、週期、連續 4 小時、公告" do
    figures = { cycle_rows: [ cycle_row(8, 150.0, 149.0) ], four_hours: rule, versions: [ version(periods: [ period(6, 8, 4, 6, on_road: 10.0) ]) ] }
    expect(sentences(**figures).map { it[0, 2] }).to eq(%w[停車 08 能判 尖峰])
  end
end
