# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardLayoversComponent, type: :component do
  # 15373 stops only at the end of direction 1; 9001 stops at both.
  def month_card(route_id: 15373) = RoutePage::MonthCard.new(create(:route_card, route_id:))

  def store(day = "2026-10-19", route_id: 15373, **attributes)
    create(:route_day, route_id:, day: Date.iso8601(day), **attributes).tap do |route_day|
      route_day.stops.create!([ { route_id:, go_back: 0, seq: 4, stop_name: "青年公園" }, { route_id:, go_back: 1, seq: 9, stop_name: "天母" } ])
    end
  end

  # `count` layovers of `minutes` minutes ending at `clock`, each with its own vehicle.
  def add_layovers(route_day, clock, count, minutes, go_back: 1)
    count.times do |index|
      end_time = Time.zone.parse("#{route_day.day} #{clock}")
      create(:layover, route_day:, go_back:, bus_id: "TEST-#{clock}-#{minutes}-#{index}", end_time:, next_start_time: end_time + minutes.minutes)
    end
  end

  def render_block(card = month_card) = render_inline(described_class.new(month_card: card))

  def table_row(set, go_back) = page.find("tr[data-set='#{set}'][data-go-back='#{go_back}']").all("td").map(&:text)

  describe "表" do
    it "一列寫日型別、結束那趟、末站、折返方式、筆數、p10、p50、p90 與不到 15 分鐘" do
      add_layovers(store, "08:00", 2, 10)
      add_layovers(RouteDay.first, "09:00", 2, 20)
      render_block
      expect(table_row("weekday", 1)).to eq([ "平日", "返程", "天母", "停車", "4", "10.0", "15.0", "20.0", "50.0%" ])
    end

    it "直接折返那一端也有一列" do
      add_layovers(store, "08:00", 1, 3, go_back: 0)
      render_block
      expect(table_row("weekday", 0).values_at(1, 2, 3, 4)).to eq([ "去程", "青年公園", "直接折返", "1" ])
    end

    it "停車端排在直接折返端前面" do
      store
      render_block
      expect(page.all("tr[data-set='weekday']").map { it["data-go-back"] }).to eq(%w[1 0])
    end

    it "這個月沒有假日：假日那幾列寫 —，站名借平日的" do
      store
      render_block
      expect(table_row("holiday", 1)).to eq([ "假日", "返程", "天母", "停車", "—", "—", "—", "—", "—" ])
    end

    it "一天都沒有存：站名也是 —" do
      render_block
      expect(table_row("weekday", 1).values_at(2, 4)).to eq([ "—", "—" ])
    end
  end

  describe "直接折返那一句" do
    it "有直接折返端：寫出來" do
      render_block
      expect(page).to have_css("[data-pass-through-note]")
    end

    it "兩端都停車：不寫" do
      render_block(month_card(route_id: 9001))
      expect(page).to have_no_css("[data-pass-through-note]")
    end
  end

  describe "依車回來的小時" do
    before do
      route_day = store
      add_layovers(route_day, "08:10", 8, 10)
      add_layovers(route_day, "08:40", 2, 20)
      add_layovers(route_day, "23:10", 6, 5)
      render_block
    end

    def bar(hour) = page.find("[data-hour-bar='#{hour}']", visible: :all)

    it "08 時印 80 與 10" do
      expect(bar(8).all("text", visible: :all).map(&:text)).to eq(%w[08 80 10])
    end

    it "23 時印 100 與 6" do
      expect(bar(23).all("text", visible: :all).map(&:text)).to eq(%w[23 100 6])
    end

    it "筆數不到 10 的柱子分開畫" do
      expect([ bar(8)["data-few-layovers"], bar(23)["data-few-layovers"] ]).to eq([ nil, "true" ])
    end

    it "直接折返那一端沒有這張圖" do
      expect(page.all("[data-hour-chart]", visible: :all).map { it["data-hour-chart"] }).to eq(%w[1])
    end
  end

  describe "分佈" do
    before do
      add_layovers(store, "08:00", 2, 3)
      add_layovers(RouteDay.first, "09:00", 1, 20)
      render_block
    end

    def bins = page.all("[data-bin]", visible: :all)

    it "六個分箱的筆數" do
      expect(bins.map { it["data-count"].to_i }).to eq([ 2, 0, 0, 1, 0, 0 ])
    end

    it "不到 15 分鐘的分箱標出來" do
      expect(bins.map { it["data-short"] }).to eq([ "true", "true", "true", nil, nil, nil ])
    end

    it "15 分鐘那裡一條線" do
      expect(page).to have_css("[data-short-boundary]", visible: :all)
    end
  end

  describe "兩個停車端" do
    before do
      route_day = store(route_id: 9001)
      add_layovers(route_day, "08:00", 1, 10, go_back: 0)
      add_layovers(route_day, "08:00", 1, 10, go_back: 1)
      render_block(month_card(route_id: 9001))
    end

    it "各一組圖" do
      expect(page.all("[data-hour-chart]", visible: :all).map { it["data-hour-chart"] }).to eq(%w[0 1])
    end

    it "圖名寫末站名" do
      expect(page.all("[data-chart-caption]").map(&:text).first).to include("青年公園")
    end
  end

  it "停車端沒有折返停留：不畫圖" do
    store
    render_block
    expect(page).to have_no_css("[data-hour-chart]", visible: :all)
  end
end
