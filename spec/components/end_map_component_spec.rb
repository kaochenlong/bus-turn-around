# frozen_string_literal: true

require "rails_helper"

RSpec.describe EndMapComponent, type: :component do
  def tiles = MapTiles::Tiles.new(url: "https://tiles.example.test/{z}/{x}/{y}.png", attribution: "測試顯名", max_zoom: 17)

  # Direction 0 of a stored day: 戊站 with the fixture's one cell of 25 of 29 reports and two toilet places.
  def store_end(reports: 29, cells: [ [ 25.0604, 121.5002, 25 ] ], place_name: "戊站公園-男廁")
    route_day_end = create(:route_day_end, n_standstill_records: reports)
    cells.each { |lat, lon, n_records| create(:route_day_end_cell, route_day_end:, cell_latitude: lat, cell_longitude: lon, n_records:) }
    create(:route_day_end_toilet, route_day_end:, name: place_name, address: "戊路2號", meters: 251.7)
    create(:route_day_end_toilet, route_day_end:, name: "戊站加油站-混合廁所", address: "戊路1號", meters: 451.9, latitude: 25.064486)
  end

  def map_end = RoutePage::EndMap.new(RouteDay.order(:day), ends: RoutePage.ends(9001)).ends.find { it.go_back.zero? }

  def render_map = render_inline(described_class.new(end: map_end, tiles:))

  def json(rendered) = JSON.parse(rendered.at_css("[data-end-map] script[type='application/json'][data-end-map-data]").text)

  # Every key and every string value anywhere in the map data.
  def keys_and_strings(value)
    case value
    when Hash then value.flat_map { |key, inner| [ key, *keys_and_strings(inner) ] }
    when Array then value.flat_map { keys_and_strings(it) }
    when String then [ value ]
    else []
    end
  end

  describe "一端的地圖" do
    let(:rendered) { store_end.then { render_map } }

    it "地圖資料是一段可解析的 JSON，鍵名齊全" do
      expect(json(rendered).keys).to eq(%w[goBack nature lastStop nextFirstStop location places cells cellsBeyondExtent cellDegrees extentMeters minZoom coverage])
    end

    it "座標都是數字：末站、位置、處與格子" do
      data = json(rendered)
      coordinates = [ data["lastStop"], data["location"], *data["places"], *data["cells"] ].flat_map { it.values_at("lat", "lon") }
      expect(coordinates).to all(be_a(Float))
    end

    it "沒有任何以 bus 開頭的鍵，也沒有車牌形狀的值" do
      expect(keys_and_strings(json(rendered)).grep(/\Abus|\A[0-9A-Z]{2,4}-[0-9A-Z]{2,4}\z/i)).to eq([])
    end

    it "容器帶 pending 狀態、圖磚網址、顯名與最大縮放，對輔助科技隱藏" do
      container = rendered.at_css("[data-end-map]")
      expect(container.attributes.transform_values(&:value).slice("data-map", "data-end", "data-tile-url", "data-tile-attribution", "data-max-zoom", "aria-hidden", "x-data"))
        .to eq("data-map" => "pending", "data-end" => "0", "data-tile-url" => "https://tiles.example.test/{z}/{x}/{y}.png", "data-tile-attribution" => "測試顯名",
               "data-max-zoom" => "17", "aria-hidden" => "true", "x-data" => "endMap")
    end

    it "容器帶畫圖時要寫在地圖上的字：兩個站牌、位置、公廁那一行與圖例的兩端，公廁那一行留著公尺與間數給腳本填" do
      labels = JSON.parse(rendered.at_css("[data-end-map]")["data-labels"])
      expect([ labels.keys, labels["toilet"].scan(/\{\w+\}/) ]).to eq([ %w[lastStop nextFirstStop location toilet few many], %w[{meters} {count}] ])
    end

    it "容器帶共用地圖設定要寫的字：可解析的 JSON，手勢提示與全螢幕按鈕的四個鍵，wheelZoom 留著 {key} 給腳本填" do
      gestures = JSON.parse(rendered.at_css("[data-end-map]")["data-base-map-labels"])
      expect([ gestures.keys, gestures["wheelZoom"].scan(/\{\w+\}/) ]).to eq([ %w[wheelZoom twoFingers fullscreen exitFullscreen], %w[{key}] ])
    end

    it "容器裡依序是地圖資料、那一句與畫布" do
      expect(rendered.at_css("[data-end-map]").element_children.map { it.attributes.keys.grep(/\Adata-/).first }).to eq(%w[data-end-map-data data-map-note data-map-canvas])
    end

    it "容器之後一行寫涵蓋比例：25 / 29 是 86%" do
      expect(rendered.at_css("[data-end-map] + p[data-map-coverage] [data-value=coverage-share]")&.text).to eq("86%")
    end
  end

  it "這幾天沒有任何靜止回報時，那一行說沒有靜止回報，不寫比例" do
    store_end(reports: 0, cells: [])
    coverage = render_map.at_css("p[data-map-coverage]")
    expect([ coverage.key?("data-no-reports"), coverage.css("[data-value=coverage-share]").size ]).to eq([ true, 0 ])
  end

  it "有 2 格在 1 公里外時，那一行另外寫出 2 格" do
    store_end(reports: 40, cells: [ [ 25.0604, 121.5002, 25 ], [ 25.0870, 121.5000, 5 ], [ 25.0872, 121.5000, 5 ] ])
    expect(render_map.at_css("p[data-map-coverage] [data-value=cells-beyond-extent]")&.text).to eq("2")
  end

  it "沒有格子在 1 公里外時不寫那一句" do
    store_end
    expect(render_map.css("p[data-map-coverage] [data-value=cells-beyond-extent]").size).to eq(0)
  end

  it "名稱裡有 </script> 時，地圖資料仍是同一段，名稱照原樣解析回來" do
    store_end(place_name: "</script><script>alert(1)</script>")
    rendered = render_map
    expect([ rendered.css("script").size, json(rendered)["places"].first["name"] ]).to eq([ 1, "</script><script>alert(1)</script>" ])
  end
end
