# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteMapComponent, type: :component do
  def tiles = MapTiles::Tiles.new(url: "https://tiles.example.test/{z}/{x}/{y}.png", attribution: "測試顯名", max_zoom: 17)

  # Route 9001 on 2026-10-19: both directions' first and last stops and their
  # route shapes as on the fixture day, direction 0's first stop named `first_name`.
  def store_day(first_name: "甲站")
    route_day = create(:route_day, day: Date.new(2026, 10, 19))
    route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: first_name, latitude: 25.05, longitude: 121.5 },
                              { go_back: 0, seq: 4, stop_name: "戊站", latitude: 25.06, longitude: 121.5 },
                              { go_back: 1, seq: 5, stop_name: "戊站對面", latitude: 25.06, longitude: 121.5003 },
                              { go_back: 1, seq: 9, stop_name: "甲站", latitude: 25.05, longitude: 121.5003 } ])
    create(:route_day_shape, route_day:, go_back: 0)
    create(:route_day_shape, route_day:, go_back: 1, shape_updated_at: Time.zone.parse("2023-12-29 09:48:24"), points: [ [ 25.06, 121.5003 ], [ 25.05, 121.5003 ] ])
  end

  def render_map = render_inline(described_class.new(route_shape: RoutePage::RouteShape.new(RouteDay.order(:day)), tiles:))

  def json(rendered) = JSON.parse(rendered.at_css("[data-route-map] script[type='application/json'][data-route-map-data]").text)

  # Every key and every string value anywhere in the map data.
  def keys_and_strings(value)
    case value
    when Hash then value.flat_map { |key, inner| [ key, *keys_and_strings(inner) ] }
    when Array then value.flat_map { keys_and_strings(it) }
    when String then [ value ]
    else []
    end
  end

  describe "有路線軌跡時" do
    let(:rendered) { store_day.then { render_map } }

    it "地圖資料是一段可解析的 JSON，鍵名齊全" do
      data = json(rendered)
      expect([ data.keys, data["lines"].first.keys, data["endStops"].first.keys, data["endStops"].first["first"].keys ])
        .to eq([ %w[lines endStops], %w[goBack points], %w[goBack first last], %w[name lat lon] ])
    end

    it "兩個方向的線照方向排，點照存下來的順序" do
      expect(json(rendered)["lines"].map { [ it["goBack"], it["points"].values_at(0, -1) ] })
        .to eq([ [ 0, [ [ 25.05, 121.5 ], [ 25.06, 121.5 ] ] ], [ 1, [ [ 25.06, 121.5003 ], [ 25.05, 121.5003 ] ] ] ])
    end

    it "每個方向的起站與末站帶名稱與座標" do
      expect(json(rendered)["endStops"].map { [ it["goBack"], *it.values_at("first", "last").map { |stop| stop.values_at("name", "lat", "lon") } ] })
        .to eq([ [ 0, [ "甲站", 25.05, 121.5 ], [ "戊站", 25.06, 121.5 ] ], [ 1, [ "戊站對面", 25.06, 121.5003 ], [ "甲站", 25.05, 121.5003 ] ] ])
    end

    it "座標都是數字：線上的點與起站末站" do
      data = json(rendered)
      coordinates = data["lines"].flat_map { it["points"].flatten } + data["endStops"].flat_map { [ it["first"], it["last"] ] }.flat_map { it.values_at("lat", "lon") }
      expect(coordinates).to all(be_a(Float))
    end

    it "沒有任何以 bus 開頭的鍵，也沒有車牌形狀的值" do
      expect(keys_and_strings(json(rendered)).grep(/\Abus|\A[0-9A-Z]{2,4}-[0-9A-Z]{2,4}\z/i)).to eq([])
    end

    it "容器帶 pending 狀態、圖磚網址、顯名與最大縮放，對輔助科技隱藏" do
      container = rendered.at_css("[data-route-map]")
      expect(container.attributes.transform_values(&:value).slice("data-map", "data-tile-url", "data-tile-attribution", "data-max-zoom", "aria-hidden", "x-data"))
        .to eq("data-map" => "pending", "data-tile-url" => "https://tiles.example.test/{z}/{x}/{y}.png", "data-tile-attribution" => "測試顯名",
               "data-max-zoom" => "17", "aria-hidden" => "true", "x-data" => "routeMap")
    end

    it "容器帶畫圖時要寫在地圖上的字：圖例的兩個方向，與每個方向的起站、末站" do
      labels = JSON.parse(rendered.at_css("[data-route-map]")["data-labels"])
      expect([ labels.keys, labels.values.map(&:keys) ]).to eq([ %w[directions firstStop lastStop], [ %w[0 1] ] * 3 ])
    end

    it "容器帶共用地圖設定要寫的字：可解析的 JSON，手勢提示與全螢幕按鈕的四個鍵，wheelZoom 留著 {key} 給腳本填" do
      gestures = JSON.parse(rendered.at_css("[data-route-map]")["data-base-map-labels"])
      expect([ gestures.keys, gestures["wheelZoom"].scan(/\{\w+\}/) ]).to eq([ %w[wheelZoom twoFingers fullscreen exitFullscreen], %w[{key}] ])
    end

    it "容器裡依序是地圖資料、那一句與畫布" do
      expect(rendered.at_css("[data-route-map]").element_children.map { it.attributes.keys.grep(/\Adata-/).first }).to eq(%w[data-route-map-data data-map-note data-map-canvas])
    end

    it "容器之後一行只寫資料來源與公運處更新日 2023-12-29，沒有快照日 2026-10-19" do
      source = rendered.at_css("[data-route-map] + p[data-route-shape-source]")
      expect([ source["data-updated-on"], source.key?("data-static-day"), source.text.include?("2023-12-29"), source.text.include?("2026-10-19") ])
        .to eq([ "2023-12-29", false, true, false ])
    end

    it "沒有說涵蓋的日子沒有路線軌跡" do
      expect(rendered.css("[data-no-route-shape]").size).to eq(0)
    end
  end

  it "涵蓋的日子都沒有路線軌跡：只有那一句，沒有地圖容器也沒有來源那一行" do
    create(:route_day, day: Date.new(2026, 10, 19))
    rendered = render_map
    expect(%w[[data-no-route-shape] [data-route-map] [data-route-shape-source]].map { rendered.css(it).size }).to eq([ 1, 0, 0 ])
  end

  it "站名裡有 </script> 時，地圖資料仍是同一段，名稱照原樣解析回來" do
    store_day(first_name: "</script><script>alert(1)</script>")
    rendered = render_map
    expect([ rendered.css("script").size, json(rendered)["endStops"].first["first"]["name"] ]).to eq([ 1, "</script><script>alert(1)</script>" ])
  end
end
