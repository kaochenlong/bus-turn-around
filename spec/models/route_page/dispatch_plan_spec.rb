require "rails_helper"

RSpec.describe RoutePage::DispatchPlan, type: :model do
  # Route 9001: the weekday 10-16, the weekdays 10-19 to 10-23 and the
  # holidays 10-24 to 10-26.
  def store_days
    [ Date.new(2026, 10, 16), *(Date.new(2026, 10, 19)..Date.new(2026, 10, 23)) ].each { create(:route_day, day: it) }
    (Date.new(2026, 10, 24)..Date.new(2026, 10, 26)).each { create(:route_day, day: it, day_type: "holiday") }
  end

  def plan(type, today: Date.new(2026, 10, 27)) = described_class.new(route_id: 9001, type:, today:)

  def covered(type) = plan(type).coverage.route_days.map { it.day.iso8601 }

  it "規格的照星期幾決定日型別：沒有指定時，星期一到五是平日，星期六日是假日" do
    days = %w[2026-10-26 2026-10-30 2026-10-31 2026-11-01].map { Date.iso8601(it) }
    expect(days.map { described_class.day_type(nil, it) }).to eq(%w[weekday weekday holiday holiday])
  end

  it "指定的日型別優先於星期幾；空的當作沒有指定" do
    expect([ described_class.day_type("weekday", Date.new(2026, 10, 31)), described_class.day_type("holiday", Date.new(2026, 10, 26)), described_class.day_type("", Date.new(2026, 10, 31)) ])
      .to eq(%w[weekday holiday holiday])
  end

  it "不認得的日型別：跟班表頁不收的參數一樣丟 InvalidParameter" do
    expect { plan("sunday") }.to raise_error(RoutePage::Coverage::InvalidParameter)
  end

  it "平日的計畫涵蓋最新的平日 10-23 往前 7 天內的平日：10-19 到 10-23，不含 10-16" do
    store_days
    expect(covered(nil)).to eq(%w[2026-10-19 2026-10-20 2026-10-21 2026-10-22 2026-10-23])
  end

  it "假日的計畫涵蓋最新的假日 10-26 往前 7 天內的假日：10-24 到 10-26" do
    store_days
    expect(covered("holiday")).to eq(%w[2026-10-24 2026-10-25 2026-10-26])
  end

  it "這條路線沒有那個日型別的資料時沒有計畫：別條路線的假日不算" do
    create(:route_day, day: Date.new(2026, 10, 19)).then { create(:route_day, route_id: 9002, day: Date.new(2026, 10, 25), day_type: "holiday") }
    expect([ plan("holiday").coverage, plan("weekday").coverage&.day ]).to eq([ nil, Date.new(2026, 10, 19) ])
  end
end
