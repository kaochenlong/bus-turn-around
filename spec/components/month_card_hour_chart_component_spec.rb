# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardHourChartComponent, type: :component do
  def series(key, points, color: "#0d9488") = described_class::Series.new(key:, color:, points:)

  def render_chart(**options)
    render_inline(described_class.new(aria_label: "圖", height: 200, first_hour: 5, last_hour: 24, ticks: [ 0, 5, 10, 15 ], **options))
  end

  describe ".ticks_for" do
    [ [ 0, 15, [ 0, 5, 10, 15 ] ], [ 0, 46, [ 0, 10, 20, 30, 40, 50 ] ], [ 0, 78, [ 0, 20, 40, 60, 80 ] ], [ 0, 8, [ 0, 2, 4, 6, 8 ] ], [ 0, 3, [ 0, 1, 2, 3 ] ],
      [ 105, 215, [ 100, 120, 140, 160, 180, 200, 220 ] ] ].each do |low, high, ticks|
      it "#{low} 到 #{high}：#{ticks.join('、')}" do
        expect(described_class.ticks_for(low, high)).to eq(ticks)
      end
    end

    it "沒有資料：0 到 1" do
      expect(described_class.ticks_for(0, 0)).to eq([ 0, 1 ])
    end
  end

  it "每個系列一條線，一個點一個圓，點帶小時與值" do
    render_chart(series: [ series("go", [ [ 6.5, 5.5 ], [ 7.5, 2.5 ] ]), series("back", [ [ 6.5, 1.0 ] ], color: "#c2570c") ])
    expect(page.all("[data-series='go'] circle", visible: :all).map { [ it["data-hour"], it["data-value"] ] }).to eq([ [ "6.5", "5.5" ], [ "7.5", "2.5" ] ])
  end

  it "線上的點照值畫：值大的比較高" do
    render_chart(series: [ series("go", [ [ 6.5, 5.5 ], [ 7.5, 2.5 ] ]) ])
    circles = page.all("[data-series='go'] circle", visible: :all)
    expect(circles.first["cy"].to_f).to be < circles.last["cy"].to_f
  end

  it "色塊從時段的開始畫到結束，上下是範圍" do
    render_chart(bands: [ described_class::Band.new(from_hour: 6.5, to_hour: 8, low: 10, high: 15) ])
    band = page.find("[data-band]", visible: :all)
    expect(band["height"].to_f).to be > 0
  end

  it "超過畫面範圍的時段不畫到圖外面" do
    render_chart(bands: [ described_class::Band.new(from_hour: 0, to_hour: 6, low: 1, high: 2) ])
    band = page.find("[data-band]", visible: :all)
    expect(band["x"].to_f).to be >= described_class::LEFT
  end

  describe "公告上下界相同" do
    let(:band) { page.find("line[data-band]", visible: :all) }

    before { render_chart(bands: [ described_class::Band.new(from_hour: 17, to_hour: 24, low: 2, high: 2) ]) }

    it "公告值畫成水平線" do
      expect(band["y1"]).to eq(band["y2"])
    end

    it "線有可見的粗細" do
      expect(band["stroke-width"].to_f).to be_positive
    end

    it "線跨過公告的時段" do
      expect(band["x2"].to_f).to be > band["x1"].to_f
    end
  end

  it "單一公告值的線也裁切在橫軸範圍內" do
    render_chart(bands: [ described_class::Band.new(from_hour: 0, to_hour: 25, low: 2, high: 2) ])
    band = page.find("line[data-band]", visible: :all)
    expect([ band["x1"].to_f, band["x2"].to_f ]).to eq([ described_class::LEFT + 0.5, described_class::WIDTH - described_class::RIGHT - 0.5 ])
  end

  it "整個在畫面範圍外的時段不畫" do
    render_chart(bands: [ described_class::Band.new(from_hour: 0, to_hour: 4, low: 1, high: 2) ])
    expect(page).to have_no_css("[data-band]", visible: :all)
  end

  it "標出來的小時畫底色" do
    render_chart(shaded_hours: [ 8, 10 ])
    expect(page.all("[data-shaded-hour]", visible: :all).map { it["data-shaded-hour"] }).to eq(%w[8 10])
  end

  it "標註印在時段上方" do
    render_chart(notes: [ described_class::Note.new(hour: 7.25, value: 15, text: "公告 4–6 分一班") ])
    expect(page.find("[data-chart-note]", visible: :all).text).to eq("公告 4–6 分一班")
  end

  it "橫軸每小時一格，到最後一個小時之前" do
    render_chart
    expect(page.all("[data-hour-tick]", visible: :all).map(&:text)).to eq((5..23).map { format("%02d", it) })
  end

  it "縱軸的刻度" do
    render_chart
    expect(page.all("[data-value-tick]", visible: :all).map(&:text)).to eq(%w[0 5 10 15])
  end

  it "有替代文字" do
    render_chart
    expect(page.find("svg", visible: :all)["aria-label"]).to eq("圖")
  end
end
