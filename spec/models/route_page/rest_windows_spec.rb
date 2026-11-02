require "rails_helper"

RSpec.describe RoutePage::RestWindows, type: :model do
  def figures(relation = RouteDay.all) = described_class.new(relation)

  # A stored day with windows of a rule: `total` of them, of which `flagged` are
  # flagged and `over` are on a vehicle over the daily driving limit.
  def store_day(day, rule: "four_hours", total: 0, flagged: 0, over: 0, route_day: create(:route_day, day: Date.iso8601(day), rest_windows_loaded: true))
    total.times do |index|
      create(:route_day_rest_window, route_day:, rule:, bus_id: "TEST-#{format('%04d', index + 1)}", flagged: index < flagged, over_daily_driving: index < over)
    end
    route_day
  end

  def stretch_minutes(route_day, *minutes)
    minutes.each_with_index do |length, index|
      create(:route_day_driving_stretch, route_day:, bus_id: "TEST-#{format('%04d', index + 1)}", end_time: Time.zone.parse("2026-10-19 06:00") + length.minutes)
    end
  end

  describe "規則的數字" do
    it "兩天：一天 4 個視窗 2 個標出、一天 2 個視窗 2 個標出，合計 6 個 4 個，比例 4/6，逐日 0.5 到 1.0" do
      store_day("2026-10-19", total: 4, flagged: 2)
      store_day("2026-10-20", total: 2, flagged: 2)
      rule = figures.rule(:four_hours)
      expect([ rule.n_windows, rule.n_flagged, rule.flagged_share, rule.day_low, rule.day_high ]).to eq([ 6, 4, 4.fdiv(6), 0.5, 1.0 ])
    end

    it "沒有視窗的日子不進逐日範圍：一天沒有 6 小時視窗，另一天 2 個 1 個標出，逐日都是 0.5" do
      store_day("2026-10-19", rule: "four_hours", total: 1)
      store_day("2026-10-20", rule: "six_hours", total: 2, flagged: 1)
      rule = figures.rule(:six_hours)
      expect([ rule.n_windows, rule.n_flagged, rule.day_low, rule.day_high ]).to eq([ 2, 1, 0.5, 0.5 ])
    end

    it "完全沒有視窗：0 個，比例與逐日都是 nil" do
      store_day("2026-10-19", rule: "four_hours", total: 1)
      rule = figures.rule(:six_hours)
      expect([ rule.n_windows, rule.n_flagged, rule.flagged_share, rule.day_low, rule.day_high ]).to eq([ 0, 0, nil, nil, nil ])
    end

    it "報落在當天行駛超過上限的車上的視窗數，以及其中標出的" do
      store_day("2026-10-19", total: 5, flagged: 2, over: 3)
      rule = figures.rule(:four_hours)
      expect([ rule.n_over_daily, rule.n_flagged_over_daily ]).to eq([ 3, 2 ])
    end

    it "兩條規則分開算" do
      day = store_day("2026-10-19", rule: "four_hours", total: 3, flagged: 1)
      store_day("2026-10-19", rule: "six_hours", total: 1, flagged: 1, route_day: day)
      expect([ figures.rule(:four_hours).n_windows, figures.rule(:six_hours).n_flagged ]).to eq([ 3, 1 ])
    end

    it "只算給定的路線日" do
      store_day("2026-10-19", total: 4)
      other = store_day("2026-10-20", total: 2)
      expect(figures(RouteDay.where(id: other.id)).rule(:four_hours).n_windows).to eq(2)
    end

    it "不認得的規則直接丟錯，不會回一個全是 0 的答案" do
      expect { figures.rule(:five_hours) }.to raise_error(KeyError)
    end

    it "傳排序過與沒排序的 relation，結果相同" do
      store_day("2026-10-19", total: 4, flagged: 2)
      store_day("2026-10-20", total: 2, flagged: 2)
      expect(figures(RouteDay.order(:day)).rule(:four_hours)).to eq(figures(RouteDay.order(day: :desc)).rule(:four_hours))
    end
  end

  describe "連續行駛段" do
    it "100、200、250、400 分鐘：4 段，p50 225.0、p90 355.0、最長 400.0，超過 4 小時 2 段、超過 6 小時 1 段" do
      stretch_minutes(store_day("2026-10-19"), 100, 200, 250, 400)
      stretches = figures.stretches
      expect([ stretches.n_stretches, stretches.p50, stretches.p90, stretches.longest, stretches.n_over_four_hours, stretches.n_over_six_hours ])
        .to eq([ 4, 225.0, 355.0, 400.0, 2, 1 ])
    end

    it "剛好 240 與 360 分鐘不算超過" do
      stretch_minutes(store_day("2026-10-19"), 240, 360)
      expect(figures.stretches.then { [ it.n_over_four_hours, it.n_over_six_hours ] }).to eq([ 1, 0 ])
    end

    it "沒有連續行駛段：0 段，分鐘數都是 nil" do
      store_day("2026-10-19")
      stretches = figures.stretches
      expect([ stretches.n_stretches, stretches.p50, stretches.p90, stretches.longest, stretches.n_over_four_hours ]).to eq([ 0, nil, nil, nil, 0 ])
    end
  end

  describe "needs_reload?" do
    it "每一天都算過視窗：false，就算那天一個視窗都沒有" do
      store_day("2026-10-19")
      expect(figures.needs_reload?).to be(false)
    end

    it "有一天還沒重算：true" do
      store_day("2026-10-19")
      create(:route_day, day: Date.new(2026, 10, 20))
      expect(figures.needs_reload?).to be(true)
    end
  end

  it "回傳值沒有車牌" do
    stretch_minutes(store_day("2026-10-19", total: 2, flagged: 1), 100)
    expect([ figures.rule(:four_hours).to_h, figures.stretches.to_h ].to_s).not_to include("TEST-")
  end
end
