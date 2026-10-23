# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteCoverageComponent, type: :component do
  before do
    create(:route_day)
  end

  def render_coverage(**params) = render_inline(described_class.new(coverage: RoutePage::Coverage.new(route_id: 9001, **params)))

  it "範圍切換的兩個連結都保留選的那一天" do
    links = render_coverage(day: "2026-10-19").css("[data-range] a").map { it["href"] }
    expect(links).to eq([ "/routes/9001?day=2026-10-19&range=day", "/routes/9001?day=2026-10-19&range=7d" ])
  end

  describe "10-19 與 10-23 是平日、10-26 是「補假」的假日時" do
    before do
      create(:route_day, day: Date.new(2026, 10, 23))
      create(:route_day, day: Date.new(2026, 10, 26), day_type: "holiday", day_note: "補假")
    end

    it "涵蓋的日子標出選的那一天的日型別，用那一類的名稱" do
      covered = render_coverage(day: "2026-10-26", range: "7d").at_css("[data-day-type]")
      expect([ covered["data-day-type"], covered.text.include?(I18n.t("day_types.holiday")) ]).to eq([ "holiday", true ])
    end

    it "10-26 跟著它的備註" do
      expect(render_coverage(day: "2026-10-26").at_css("[data-day='2026-10-26']").text.squish).to eq("2026-10-26（一）補假")
    end

    it "另一類的連結跳到 10-26 以前最近的平日 10-23，範圍不變，名稱是平日" do
      link = render_coverage(day: "2026-10-26", range: "7d").at_css("a[data-other-day-type]")
      expect([ link["data-other-day-type"], link["href"], link.text.include?(I18n.t("day_types.weekday")) ]).to eq([ "weekday", "/routes/9001?day=2026-10-23&range=7d", true ])
    end

    it "10-23 以前沒有已寫入的假日，就沒有另一類的連結" do
      expect(render_coverage(day: "2026-10-23", range: "7d").css("a[data-other-day-type]")).to be_empty
    end
  end
end
