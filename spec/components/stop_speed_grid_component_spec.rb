# frozen_string_literal: true

require "rails_helper"

RSpec.describe StopSpeedGridComponent, type: :component do
  # A stored day of route 9001 whose outbound stops 甲站, 乙站, 丙站 are at 0,
  # 300 and 600 metres along the shape; `inbound` adds two inbound stops.
  def route_day(inbound: false)
    create(:route_day).tap do |route_day|
      [ [ 0, "甲站", 0.0 ], [ 1, "乙站", 300.0 ], [ 2, "丙站", 600.0 ] ].each { |seq, stop_name, shape_meters| route_day.stops.create!(go_back: 0, seq:, stop_name:, shape_meters:) }
      [ [ 5, "丙站對面", 0.0 ], [ 6, "甲站", 600.0 ] ].each { |seq, stop_name, shape_meters| route_day.stops.create!(go_back: 1, seq:, stop_name:, shape_meters:) } if inbound
    end
  end

  # One new trip of `route_day` per [seq, band, metres, seconds, go_back], each
  # with that one stop speed row.
  def speeds(route_day, rows)
    rows.each do |seq, band, meters, seconds, go_back = 0|
      start_time = Time.zone.parse("2026-10-19 06:00")
      route_day.trips.create!(bus_id: "TEST-#{Trip.count + 1}", path_attribute_id: 9001, go_back:, band:, start_time:, end_time: start_time + 1.hour,
                              first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                              start_from_arrival: false, end_from_departure: false).stop_speeds.create!(seq:, band:, meters:, seconds:)
    end
  end

  # Leg 0 outbound: five trips at 5.0 km/h in the morning peak, five at 20.0 in
  # the daytime, two in the evening peak and none in the other band.
  def mixed_day(inbound: false)
    route_day(inbound:).tap { speeds(it, [ [ 0, "morning_peak", 100.0, 72 ] ] * 5 + [ [ 0, "daytime", 100.0, 18 ] ] * 5 + [ [ 0, "evening_peak", 100.0, 36 ] ] * 2) }
  end

  def render_grid(day) = render_inline(described_class.new(stop_speeds: RoutePage::StopSpeeds.new(RouteDay.where(id: day.id))))

  def cell(page, band) = page.at_css("[data-section=stop-speeds] [data-direction='0'] svg rect[data-seq='0'][data-band='#{band}']")

  describe "格子圖" do
    let(:page) { render_grid(mixed_day) }

    it "有顏色的格子帶級數：早尖峰 5.0 公里是 4 級、日間 20.0 公里是 1 級" do
      expect(%w[morning_peak daytime].map { cell(page, it)["data-level"] }).to eq(%w[4 1])
    end

    it "樣本少的格子帶 data-small-sample、沒有列的格子帶 data-no-speed，兩者都沒有級數" do
      evening, other = %w[evening_peak other].map { cell(page, it) }
      expect([ evening.key?("data-small-sample"), other.key?("data-no-speed"), evening["data-level"], other["data-level"] ]).to eq([ true, true, nil, nil ])
    end

    it "四列照早尖峰、日間、晚尖峰、其餘排，每一列的格子照站序" do
      bands = page.css("[data-direction='0'] svg rect[data-seq]").map { it["data-band"] }.uniq
      expect([ bands, page.css("[data-direction='0'] svg rect[data-band='daytime']").map { it["data-seq"] } ]).to eq([ %w[morning_peak daytime evening_peak other], %w[0 1] ])
    end

    it "格子圖裡沒有 title 元素，滑鼠移上去不會跳出提示框" do
      expect(page.css("[data-section=stop-speeds] svg title")).to be_empty
    end

    it "每一站的名字都寫在格子圖上" do
      expect(page.css("[data-direction='0'] svg [data-stop-label]").map(&:text)).to eq(%w[甲站 乙站 丙站])
    end

    it "格子下面每一站一個站點，起訖兩站的站點標成端點" do
      expect(page.css("[data-direction='0'] svg [data-stop-mark]").map { it.key?("data-terminal") }).to eq([ true, false, true ])
    end
  end

  describe "圖例與時速範圍" do
    let(:page) { render_grid(mixed_day) }

    it "圖例四個色塊，從 1 級到 4 級" do
      expect(page.css("[data-stop-speed-legend] [data-legend-level]").map { it["data-legend-level"] }).to eq(%w[1 2 3 4])
    end

    it "去程的時速範圍照最慢那一格的 5.0 公里算：20.0、10.0、6.7" do
      expect(page.at_css("[data-direction='0'] [data-level-ranges]")["data-level-bounds"]).to eq("20.0,10.0,6.7")
    end

    it "沒有夠樣本的格子的方向沒有時速範圍那一行" do
      day = mixed_day(inbound: true).tap { speeds(it, [ [ 5, "daytime", 100.0, 36, 1 ] ]) }
      expect(render_grid(day).at_css("[data-direction='1'] [data-level-ranges]")).to be_nil
    end
  end

  describe "數字表" do
    let(:page) { render_grid(mixed_day) }

    it "收在預設關閉的 details 裡，去程每個兩站之間一列，帶沿線的公尺數" do
      details = page.at_css("[data-section=stop-speeds] details[data-stop-speed-table]")
      expect([ details.key?("open"), details.css("[data-table-direction='0'] tr[data-seq]").map { [ it["data-seq"], it["data-meters"] ] } ]).to eq([ false, [ %w[0 300.0], %w[1 300.0] ] ])
    end

    it "每格帶時速與趟數，樣本少的格子帶 data-small-sample，沒有列的格子沒有時速" do
      cells = page.css("[data-table-direction='0'] tr[data-seq='0'] td[data-band]").to_h { [ it["data-band"], [ it["data-kmh"], it["data-trips"], it.key?("data-small-sample") ] ] }
      expect(cells).to eq("morning_peak" => [ "5.0", "5", false ], "daytime" => [ "20.0", "5", false ], "evening_peak" => [ "10.0", "2", true ], "other" => [ nil, "0", false ])
    end
  end

  describe "沒有資料" do
    it "涵蓋的日子沒有任何站間車速時，只有標題與那一句，沒有格子圖、圖例與表" do
      page = render_grid(route_day)
      expect([ page.css("[data-no-stop-speeds]").size, page.css("svg, [data-stop-speed-legend], details").size ]).to eq([ 1, 0 ])
    end

    it "有資料、但返程沒有任何有位置的站時，返程寫那一句，去程照樣畫" do
      page = render_grid(mixed_day)
      expect([ page.css("[data-no-stop-speeds-for='1']").size, page.css("[data-direction='0'] svg").size ]).to eq([ 1, 1 ])
    end
  end

  describe "窄螢幕" do
    let(:page) { render_grid(mixed_day(inbound: true).tap { speeds(it, [ [ 5, "daytime", 100.0, 36, 1 ] ]) }) }

    # Classes and attributes that hide an element on the server's output.
    def hidden_marks(node) = [ *(node.classes & %w[hidden max-sm:hidden]), *("x-cloak" if node.key?("x-cloak")) ]

    it "沒有 JavaScript 時兩個方向的每段一列與格子圖都在回應裡，方向那一層都沒有標成藏起來" do
      directions = page.css("[data-section=stop-speeds] [data-direction]").map { [ it["data-direction"], it.css("[data-leg-row]").size, it.css("svg").size, hidden_marks(it) ] }
      expect(directions).to eq([ [ "0", 2, 1, [] ], [ "1", 1, 1, [] ] ])
    end

    it "方向切換帶 x-cloak，沒有 JavaScript 時藏著" do
      expect(page.at_css("[data-section=stop-speeds] [data-direction-switch]")&.key?("x-cloak")).to be(true)
    end

    it "每段一列的四個方塊照時段排，帶跟格子圖同樣的級數、樣本少與量不到" do
      squares = page.css("[data-direction='0'] [data-leg-row][data-seq='0'] [data-band]").map { [ it["data-band"], it["data-level"], it.key?("data-small-sample"), it.key?("data-no-speed") ] }
      expect(squares).to eq([ [ "morning_peak", "4", false, false ], [ "daytime", "1", false, false ], [ "evening_peak", nil, true, false ], [ "other", nil, false, true ] ])
    end
  end

  it "輸出裡沒有任何車牌" do
    expect(render_grid(mixed_day).to_html).not_to include("TEST-")
  end
end
