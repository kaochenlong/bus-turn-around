# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardHistoryComponent, type: :component do
  let(:october) { Date.new(2026, 10, 1) }
  let(:september) { Date.new(2026, 9, 1) }

  def card_for(month = october, route_id: 15373, coverage: { "calendar_weekdays" => 20, "calendar_holidays" => 11, "loaded_weekdays" => 18, "loaded_holidays" => 5, "missing" => [] }, **attributes)
    create(:route_card, route_id:, month:, coverage:, **attributes)
  end

  def render_block(card = card_for) = render_inline(described_class.new(month_card: RoutePage::MonthCard.new(card)))

  def store(day, route_id: 15373, **attributes)
    create(:route_day, route_id:, day: Date.iso8601(day), rest_windows_loaded: true, published_schedule_day: Date.iso8601(day), **attributes).tap do |route_day|
      route_day.stops.create!([ { route_id:, go_back: 0, seq: 4, stop_name: "青年公園", stop_location_id: 1 }, { route_id:, go_back: 1, seq: 9, stop_name: "天母", stop_location_id: 2 } ])
    end
  end

  def add_layovers(route_day, *minutes, go_back: 1)
    end_time = Time.zone.parse("#{route_day.day} 08:00")
    minutes.each_with_index { |length, index| create(:layover, route_day:, go_back:, bus_id: "TEST-#{index}", end_time:, next_start_time: end_time + length.minutes) }
  end

  def month_rows = page.all("[data-month-row]")

  describe "逐月表" do
    it "第一份：一列，說還沒有上個月可以比" do
      render_block
      expect([ month_rows.size, page.find("[data-history-lead]").text.include?("這是第一份，還沒有上個月可以比") ]).to eq([ 1, true ])
    end

    it "有上一份：兩列，舊的在前，不說第一份" do
      card_for(september)
      render_block
      expect([ month_rows.map { it["data-month-row"] }, page.find("[data-history-lead]").text.include?("這是第一份") ]).to eq([ %w[2026-09 2026-10], false ])
    end

    it "部分月份寫在月份旁邊" do
      render_block(card_for(coverage: { "calendar_weekdays" => 20, "calendar_holidays" => 11, "loaded_weekdays" => 7, "loaded_holidays" => 3, "missing" => [] }))
      expect(month_rows.sole.find("td", match: :first).text).to eq("2026-10（部分月份）")
    end

    # A day with two layovers, a flagged window, a morning period and a vehicle on the road in it.
    def store_full_day
      store("2026-10-19").tap do |route_day|
        add_layovers(route_day, 10, 20)
        create(:route_day_rest_window, route_day:, flagged: true)
        create(:route_day_published_headway, route_day:, route_id: 15373, start_minute: 360, end_minute: 420)
        create(:trip, route_day:, start_time: Time.zone.parse("2026-10-19 06:00"), end_time: Time.zone.parse("2026-10-19 07:00"))
      end
    end

    it "一列的數字：平日天數、不到 15 分鐘、逐日範圍、p10、兩條規則、早尖峰路上的車" do
      store_full_day
      render_block
      expect(month_rows.sole.all("td").map(&:text).drop(1)).to eq([ "1", "50.0%", "50%–50%", "11.0 分", "100.0%", "—", "1 台" ])
    end

    it "沒有資料：—" do
      render_block
      expect(month_rows.sole.all("td").map(&:text).drop(2).uniq).to eq([ "—" ])
    end

    it "兩個停車端：每個月兩列，寫末站名" do
      add_layovers(store("2026-10-19", route_id: 9001), 10, go_back: 0)
      render_block(card_for(route_id: 9001))
      expect(page.all("[data-end-name]").map(&:text)).to eq(%w[青年公園 天母])
    end
  end

  describe "定義改過的註明" do
    before { store("2026-09-21").tap { add_layovers(it, 10, 20) } }

    def card_with_summary(short_share)
      recomputed = RoutePage::MonthCard.new(card_for(september)).summary
      RouteCard.find_by!(month: september).update!(summary: recomputed.merge("short_share" => { "1" => short_share }))
    end

    it "舊月份存的跟重算的不同：點名那個月" do
      card_with_summary(40.0)
      render_block
      expect(page.find("[data-differing]").text).to include("2026 年 9 月")
    end

    it "相同：不寫" do
      card_with_summary(50.0)
      render_block
      expect(page).to have_no_css("[data-differing]")
    end
  end

  describe "這個月靜態快照改了什麼" do
    it "沒有改動：寫涵蓋的天數與路線軌跡的更新日" do
      [ "2026-10-19", "2026-10-20" ].each { create(:route_day_shape, route_day: store(it), shape_updated_at: Time.zone.parse("2024-11-29 16:40")) }
      render_block
      expect(page.find("[data-snapshot-changes]").text).to include("2026-10-19 到 2026-10-20 涵蓋的 2 天", "都沒有改", "路線軌跡的更新日是 2024-11-29")
    end

    it "有改動：一條一條列日期與改了什麼" do
      store("2026-10-19").tap { create(:route_day_published_headway, route_day: it, route_id: 15373) }
      store("2026-10-20").tap { create(:route_day_published_headway, route_day: it, route_id: 15373, high_minutes: 30) }
      render_block
      expect(page.all("[data-snapshot-change]").map(&:text)).to eq([ "10-20：公告班距或定時班次" ])
    end

    it "同一天改了兩樣：列在同一條" do
      store("2026-10-19")
      store("2026-10-20").tap { |day| day.stops.find_by!(go_back: 0).update!(stop_name: "青年社宅") }.tap { create(:route_day_published_headway, route_day: it, route_id: 15373) }
      render_block
      expect(page.all("[data-snapshot-change]").map(&:text)).to eq([ "10-20：公告班距或定時班次、站序" ])
    end

    it "一天都沒有存：這一段不出現" do
      render_block
      expect(page).to have_no_css("[data-snapshot-changes]")
    end
  end

  describe "逐日表" do
    it "載入的日子：星期、日型別、趟次、完整趟次、漏站率、車數、停車端筆數、比例與連續 4 小時" do
      route_day = store("2026-10-19").tap { add_layovers(it, 10, 20) }
      create(:trip, route_day:, n_stops_observed: 1)
      create(:route_day_rest_window, route_day:, flagged: true)
      render_block
      expect(page.find("tr[data-day='2026-10-19']").all("td").map(&:text)).to eq([ "10-19（一）", "平日", "1", "100%", "0.0%", "1", "2", "50%", "100%" ])
    end

    it "不到 15 分鐘畫成橫條，長度是比例" do
      add_layovers(store("2026-10-19"), 10, 20)
      render_block
      expect(page.find("tr[data-day='2026-10-19'] .meter i")[:style]).to include("width:50%")
    end

    it "補假標出來" do
      store("2026-10-26", day_type: "holiday", day_note: "補假")
      render_block
      expect(page.find("tr[data-day='2026-10-26']").all("td")[1].text).to eq("假日（補假）")
    end

    it "別的備註不標" do
      store("2026-10-25", day_type: "holiday", day_note: "光復節")
      render_block
      expect(page.find("tr[data-day='2026-10-25']").all("td")[1].text).to eq("假日")
    end

    it "少的日子：日期與原因，沒有數字" do
      store("2026-10-29")
      render_block(card_for(coverage: { "calendar_weekdays" => 20, "calendar_holidays" => 11, "loaded_weekdays" => 1, "loaded_holidays" => 0,
                                        "missing" => [ { "from" => "2026-10-30", "to" => "2026-10-30", "day_type" => "weekday", "reason" => "原始檔不齊" } ] }))
      expect(page.find("tr[data-day='2026-10-30']").all("td").map(&:text)).to eq([ "10-30（五）", "原始檔不齊" ])
    end

    it "少的日子那一格跨過日期以外的每一欄" do
      store("2026-10-29")
      render_block
      expect(page.find("tr[data-day='2026-10-30'] td[colspan]")[:colspan].to_i).to eq(page.all("[data-days] thead th").size - 1)
    end

    it "兩個停車端：每端各有筆數與比例" do
      add_layovers(store("2026-10-19", route_id: 9001), 10, go_back: 0)
      render_block(card_for(route_id: 9001))
      expect(page.find("tr[data-day='2026-10-19']").all("td").size).to eq(11)
    end

    it "一天都沒有存：沒有表" do
      render_block
      expect(page).to have_no_css("tr[data-day]")
    end
  end

  it "區塊標記是 history" do
    render_block
    expect(page).to have_css("section[data-card-section='history']")
  end
end
