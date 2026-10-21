# frozen_string_literal: true

require "rails_helper"

RSpec.describe LayoverTableComponent, type: :component do
  let(:route_day) do
    RouteDay.create!(route_id: 9001, day: Date.new(2026, 10, 19), route_name: "測試幹線", departure: "甲站",
                     destination: "戊站", static_day: Date.new(2026, 10, 19), loaded_at: Time.current).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])
    end
  end

  def cells(rendered) = rendered.css("tbody tr").map { |row| row.css("td").map { it.text.squish } }

  it "每個方向一列：方向、末站、筆數、p10、p50、p90、不到 15 分鐘的比例；沒有折返停留的方向顯示 —" do
    end_time = Time.zone.parse("2026-10-19 08:00")
    [ 10, 20, 30 ].each { route_day.layovers.create!(bus_id: "TEST-0001", go_back: 0, end_time:, next_start_time: end_time + it.minutes) }
    rendered = render_inline(described_class.new(layover_stats: RoutePage::LayoverStats.new(RouteDay.where(id: route_day.id))))
    expect(cells(rendered)).to eq([ %w[去程 戊站 3 12.0 20.0 28.0 33.3%], %w[返程 甲站 0 — — — —] ])
  end
end
