# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardMarginComponent, type: :component do
  def css(route_name: "中山幹線", partial: false, month: Date.new(2026, 10, 1))
    coverage = { "calendar_weekdays" => 20, "loaded_weekdays" => partial ? 7 : 20, "calendar_holidays" => 11, "loaded_holidays" => 0, "missing" => [] }
    create(:route_day, day: month, route_name:)
    rendered = render_inline(described_class.new(month_card: RoutePage::MonthCard.new(create(:route_card, month:, coverage:))))
    rendered.css("style").sole.text
  end

  it "路線名、月份寫在左邊的頁邊" do
    expect(css).to include("中山幹線 路線健檢卡 2026 年 10 月")
  end

  it "月份個位數不補零" do
    expect(css(month: Date.new(2026, 9, 1))).to include("2026 年 9 月")
  end

  it "部分月份標出來" do
    expect(css(partial: true)).to include("2026 年 10 月（部分月份）")
  end

  it "不是部分月份：不標" do
    expect(css).not_to include("部分月份")
  end

  it "右邊的頁邊有頁碼" do
    expect(css).to include('counter(page)', 'counter(pages)')
  end

  it "引號與反斜線先處理過，字串才不會斷掉" do
    expect(css(route_name: 'A"B\\C')).to include('A\\"B\\\\C')
  end

  it "角括號換成 CSS 的寫法，樣式標籤不會被提早結束" do
    expect(css(route_name: "A</style><script>")).to include("A\\3C /style>\\3C script>")
  end

  it "換行換成空白，字串才不會斷掉" do
    expect(css(route_name: "A\nB")).to include("A B")
  end
end
