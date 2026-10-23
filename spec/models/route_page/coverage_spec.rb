require "rails_helper"

RSpec.describe RoutePage::Coverage, type: :model do
  # Weekdays 2026-10-19 to 10-23 and the holidays 10-24 to 10-26 of route 9001.
  before do
    (Date.new(2026, 10, 19)..Date.new(2026, 10, 23)).each { create(:route_day, day: it) }
    (Date.new(2026, 10, 24)..Date.new(2026, 10, 26)).each { create(:route_day, day: it, day_type: "holiday") }
  end

  def coverage(**params) = described_class.new(route_id: 9001, **params)

  def covered(**params) = coverage(**params).route_days.map { it.day.iso8601 }

  # The number of SELECTs on route_days issued while the block runs.
  def route_days_selects
    selects = 0
    counter = ->(*, payload) { selects += 1 if payload[:name] != "SCHEMA" && payload[:sql].match?(/\ASELECT\b.*\bFROM "route_days"/m) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    selects
  end

  it "選假日的 10-26、範圍 7d：只涵蓋同類型的 10-24 到 10-26" do
    expect(covered(day: "2026-10-26", range: "7d")).to eq(%w[2026-10-24 2026-10-25 2026-10-26])
  end

  it "選假日的 10-26：另一類要跳去的日子是 10-23" do
    expect(coverage(day: "2026-10-26", range: "7d").other_type_day).to eq(Date.new(2026, 10, 23))
  end

  it "選平日的 10-23、範圍 7d：涵蓋 10-19 到 10-23" do
    expect(covered(day: "2026-10-23", range: "7d")).to eq(%w[2026-10-19 2026-10-20 2026-10-21 2026-10-22 2026-10-23])
  end

  it "選平日的 10-23：那天以前沒有已寫入的假日，另一類的日子是 nil" do
    expect(coverage(day: "2026-10-23", range: "7d").other_type_day).to be_nil
  end

  it "範圍是 day 時只涵蓋選的那一天" do
    expect(covered(day: "2026-10-26", range: "day")).to eq(%w[2026-10-26])
  end

  it "選的那一天的日型別：10-26 是 holiday、10-23 是 weekday" do
    expect([ coverage(day: "2026-10-26").day_type, coverage(day: "2026-10-23").day_type ]).to eq(%w[holiday weekday])
  end

  it "選的那一天沒有資料時，日型別與另一類的日子都是 nil" do
    expect(coverage(day: "2026-10-27").then { [ it.day_type, it.other_type_day ] }).to eq([ nil, nil ])
  end

  it "已寫入的日子與類型只查一次：預設日、有沒有資料、日型別與另一類的日子共用那一次" do
    selects = route_days_selects { coverage.then { [ it.day, it.data?, it.stored_days, it.day_type, it.other_type_day ] } }
    expect(selects).to eq(1)
  end
end
