require "rails_helper"

RSpec.describe HomePage::RouteList, type: :model do
  def store_days(route_id, *days)
    days.each do |day|
      create(:route_day, route_id:, day: Date.iso8601(day))
    end
  end

  def summary(entries) = entries.map { [ it.route_id, it.route_day&.day&.iso8601 ] }

  # The summary of the entries, with the number of SELECTs on route_days issued
  # while building and reading them.
  def summary_and_route_days_selects
    selects = 0
    counter = ->(*, payload) { selects += 1 if payload[:name] != "SCHEMA" && payload[:sql].match?(/\ASELECT\b.*\bFROM "route_days"/m) }
    summary = ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { summary(described_class.new.entries) }
    [ summary, selects ]
  end

  it "照設定的順序：15373 沒有資料是 nil，接著是 9001 最新的 2026-10-20" do
    store_days(9001, "2026-10-19", "2026-10-20")
    expect(summary(described_class.new.entries)).to eq([ [ 15373, nil ], [ 9001, "2026-10-20" ] ])
  end

  it "兩條路線各三天：只對 route_days 發一次 SELECT，15373 帶 2026-10-21、9001 帶 2026-10-20" do
    store_days(15373, "2026-10-19", "2026-10-20", "2026-10-21")
    store_days(9001, "2026-10-18", "2026-10-19", "2026-10-20")
    expect(summary_and_route_days_selects).to eq([ [ [ 15373, "2026-10-21" ], [ 9001, "2026-10-20" ] ], 1 ])
  end
end
