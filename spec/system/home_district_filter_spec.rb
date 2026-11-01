require "rails_helper"

# The district filter hides cards in the browser and keeps the district in
# the page address. Alpine does it, which component specs do not run, so it is
# checked in the browser.
RSpec.describe "首頁的行政區篩選", :js, type: :system do
  # A stored day of the route with its snapshot day set and the given
  # qualifying districts, each [county, town].
  def store_district_day(route_id, day, districts)
    create(:route_day, route_id:, day: Date.iso8601(day), stop_districts_day: Date.iso8601(day)).tap do |route_day|
      districts.each { |county, town| create(:route_day_district, route_day:, county:, town:) }
    end
  end

  # The route Ids of the cards shown, once `count` of them are.
  def shown(count)
    page.has_css?("li[data-districts]", visible: true, count:, wait: 2)
    page.all("li[data-districts]", visible: true).map { it.find("a")["data-route"] }
  end

  # The count line's text, or nil while it is hidden.
  def count_line = page.find("[data-district-count]", visible: :all).then { it.visible? ? it.text : nil }

  # The district the page address names, decoded; "" without one.
  def district_param = URI.decode_www_form_component(URI(page.current_url).query.to_s.delete_prefix("district="))

  def selected = page.find("#district-filter").value

  describe "9001 與 15373 的最新一天都有達門檻的區" do
    before do
      store_district_day(15373, "2026-10-21", [ [ "臺北市", "士林區" ] ])
      store_district_day(9001, "2026-10-20", [ [ "新北市", "甲區" ], [ "臺北市", "測試區" ] ])
    end

    it "一進來就是預設的士林區（沒有中山區）：只有 15373 的卡、那一行寫 士林區：1 條、網址沒有參數；選 測試區 只剩 9001、網址帶 ?district=測試區" do
      visit root_path
      on_load = [ shown(1), selected, count_line, district_param ]
      select "測試區", from: "district-filter"
      expect([ on_load, shown(1), count_line, district_param ]).to eq([ [ %w[15373], "士林區", "士林區：1 條", "" ], %w[9001], "測試區：1 條", "測試區" ])
    end

    it "選過別區再選回士林區：只剩 15373 的卡，網址的參數換成士林區" do
      visit root_path
      select "測試區", from: "district-filter"
      select "士林區", from: "district-filter"
      expect([ shown(1), count_line, district_param ]).to eq([ %w[15373], "士林區：1 條", "士林區" ])
    end

    it "開 /?district=新北市甲區：選單選著它、只剩 9001 的卡、那一行寫 新北市甲區：1 條" do
      visit root_path(district: "新北市甲區")
      expect([ shown(1), selected, count_line ]).to eq([ %w[9001], "新北市甲區", "新北市甲區：1 條" ])
    end

    it "開 /?district=天母：退回預設的士林區，只有 15373 的卡，網址照舊" do
      visit root_path(district: "天母")
      expect([ shown(1), selected, count_line, district_param ]).to eq([ %w[15373], "士林區", "士林區：1 條", "天母" ])
    end

    it "從帶參數的首頁去別頁再按上一頁，篩選還在" do
      visit root_path(district: "測試區")
      shown(1)
      visit route_path(9001)
      page.go_back
      expect([ shown(1), selected ]).to eq([ %w[9001], "測試區" ])
    end
  end

  describe "15373 的最新一天還沒有行政區" do
    before do
      create(:route_day, route_id: 15373, day: Date.new(2026, 10, 21))
      store_district_day(9001, "2026-10-20", [ [ "臺北市", "測試區" ] ])
    end

    it "一進來就是唯一的測試區：那一行寫 測試區：1 條，另有 1 條的資料還沒有行政區，15373 的卡藏著" do
      visit root_path
      expect([ shown(1), selected, count_line ]).to eq([ %w[9001], "測試區", "測試區：1 條，另有 1 條的資料還沒有行政區" ])
    end
  end
end
