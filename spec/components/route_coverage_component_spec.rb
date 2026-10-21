# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteCoverageComponent, type: :component do
  before do
    RouteDay.create!(route_id: 9001, day: Date.new(2026, 10, 19), route_name: "測試幹線", departure: "甲站",
                     destination: "戊站", static_day: Date.new(2026, 10, 19), loaded_at: Time.current)
  end

  def render_coverage(**params) = render_inline(described_class.new(coverage: RoutePage::Coverage.new(route_id: 9001, **params)))

  it "範圍切換的兩個連結都保留選的那一天" do
    links = render_coverage(day: "2026-10-19").css("[data-range] a").map { it["href"] }
    expect(links).to eq([ "/routes/9001?day=2026-10-19&range=day", "/routes/9001?day=2026-10-19&range=7d" ])
  end

  it "最近 7 天即使只涵蓋一天，也標出沒有分平日與假日" do
    expect(render_coverage(day: "2026-10-19", range: "7d").css("[data-no-day-type]").size).to eq(1)
  end

  it "當天的範圍不標平假日" do
    expect(render_coverage(day: "2026-10-19").css("[data-no-day-type]")).to be_empty
  end
end
