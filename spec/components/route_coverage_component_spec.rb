# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteCoverageComponent, type: :component do
  before do
    create(:route_day)
  end

  def render_coverage(**params) = render_inline(described_class.new(coverage: RoutePage::Coverage.new(route_id: 9001, **params)))

  it "h1 只有路線名稱，起迄那一行後面接著這一頁全部的路線 Id：test 設定的 9001 掛 9050" do
    header = render_coverage(day: "2026-10-19")
    route_id = header.at_css("[data-route-id]")
    expect([ header.at_css("h1")&.text, route_id&.text, route_id&.parent&.name, route_id&.parent&.text&.include?("甲站－戊站") ])
      .to eq([ "測試幹線", "路線 Id 9001・9050", "p", true ])
  end

  it "只有一個 Id 的路線，那一行一字不變" do
    allow(RoutePage).to receive(:member_route_ids).with(9001).and_return([ 9001 ])
    expect(render_coverage(day: "2026-10-19").at_css("[data-route-id]").text).to eq("路線 Id 9001")
  end

  it "選的那一天沒有資料時，沒有路線名稱的 h1，也沒有路線 Id" do
    header = render_coverage(day: "2026-10-20")
    expect([ header.css("h1").size, header.css("[data-route-id]").size ]).to eq([ 0, 0 ])
  end

  it "範圍切換的兩個連結都保留選的那一天" do
    links = render_coverage(day: "2026-10-19").css("[data-range] a").map { it["href"] }
    expect(links).to eq([ "/routes/9001?day=2026-10-19&range=day", "/routes/9001?day=2026-10-19&range=7d" ])
  end

  it "範圍是 7d 時，只有最近 7 天那個連結標成目前的範圍" do
    links = render_coverage(day: "2026-10-19", range: "7d").css("[data-range] a").map { [ it["href"], it["aria-current"] ] }
    expect(links).to eq([ [ "/routes/9001?day=2026-10-19&range=day", nil ], [ "/routes/9001?day=2026-10-19&range=7d", "true" ] ])
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
