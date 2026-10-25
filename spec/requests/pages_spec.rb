require "rails_helper"

RSpec.describe "Pages", type: :request do
  def store_days(*days)
    days.each do |day|
      create(:route_day, day: Date.iso8601(day))
    end
  end

  def page = response.parsed_body

  # A stored day of 9001 with the last stop of each direction, 戊站 for
  # direction 0 and 甲站 for direction 1, and layovers of the given minutes
  # ending in each direction.
  def store_measured_day(day, layovers: {})
    create(:route_day, day: Date.iso8601(day)).tap do |route_day|
      route_day.stops.create!([ { go_back: 0, seq: 4, stop_name: "戊站" }, { go_back: 1, seq: 9, stop_name: "甲站" } ])
      end_time = Time.zone.parse("#{day} 08:00")
      layovers.each { |go_back, minutes| minutes.each { route_day.layovers.create!(bus_id: "TEST-0001", go_back:, end_time:, next_start_time: end_time + it.minutes) } }
    end
  end

  # The number and the whole text of the line the selector names, or nils without it.
  def line_at(selector) = page.at_css(selector).then { [ it&.at_css("[data-number]")&.text, it&.text&.squish ] }

  it "首頁回 200，區塊依序是 hero、起點、路線清單、資料限制、資料來源" do
    get root_path
    expect([ response.status, page.css("[data-section]").map { it["data-section"] } ]).to eq([ 200, %w[hero origin routes limitations sources] ])
  end

  it "站名在 body 的文字裡只出現一次，就在網站名稱列裡" do
    get root_path
    name = I18n.t("site.name")
    expect([ page.at_css("body").text.scan(name).size, page.at_css("[data-site-bar]")&.text&.include?(name) ]).to eq([ 1, true ])
  end

  it "9001 存了 2026-10-20 時，不跑任何 script 拿到的 HTML 已經有插圖、起點區塊連到原文的連結、9001 的最新一天、四條資料限制與三個資料集連結" do
    store_days("2026-10-20")
    get root_path
    selectors = [ "[data-section=hero] picture", "[data-section=origin] a[href='#{OriginStoryComponent::ARTICLE_URL}']",
                  "[data-route='9001'][data-latest-day='2026-10-20']", "[data-section=limitations] li", "[data-section=sources] a[href]" ]
    expect(selectors.map { page.css(it).size }).to eq([ 1, 1, 1, 4, 3 ])
  end

  it "照設定的順序：15373 沒有資料、不是連結，接著是連到路線頁的 9001" do
    allow(RoutePage).to receive(:route_ids).and_return([ 15373, 9001 ])
    store_days("2026-10-19", "2026-10-20")
    get root_path
    expect(page.css("[data-route]").map { [ it["data-route"], it.key?("data-no-data"), it["href"] ] })
      .to eq([ [ "15373", true, nil ], [ "9001", false, "/routes/9001" ] ])
  end

  it "9001 的卡：名稱那一行只有測試幹線，甲站－戊站那一行接著路線 Id 9001・9050（test 設定掛 9050），最新一天是 2026-10-20（二）平日；9050 沒有自己的卡" do
    store_days("2026-10-19", "2026-10-20")
    get root_path
    card, route_id = page.at_css("[data-route='9001']").then { [ it, it.at_css("[data-route-id]") ] }
    expect([ card.at_css("p").text, route_id&.text, route_id&.parent&.text&.include?("甲站－戊站"), card.text, page.css("[data-route='9050']").size ])
      .to match([ "測試幹線", "路線 Id 9001・9050", true, include("2026-10-20（二）#{I18n.t('day_types.weekday')}"), 0 ])
  end

  it "沒有資料的 15373：卡上只寫路線 Id 15373，標成沒有資料，沒有連結" do
    get root_path
    card = page.at_css("[data-route='15373']")
    expect([ card.at_css("p").text, card.key?("data-no-data"), card.name, card.css("a").size ]).to eq([ "路線 Id 15373", true, "div", 0 ])
  end

  it "9001 卡上返程那一行的比例與整行文字，等於點進去的路線頁摘要「停車端停不到 15 分鐘的比例」返程那一行" do
    store_measured_day("2026-10-20", layovers: { 1 => [ 10, 20, 30 ] })
    lines = { root_path => "[data-route='9001'] [data-figure='short-share'] [data-end='1']", route_path(9001) => "[data-key-number='short-share'] [data-end='1']" }
            .map { |path, selector| get(path).then { line_at(selector) } }
    expect(lines).to eq([ [ "33.3%", "33.3% 甲站・共 3 次折返" ] ] * 2)
  end

  it "停車端有折返停留時，9001 的卡上有數字那一塊，路線清單以外的文字沒有百分比" do
    store_measured_day("2026-10-20", layovers: { 1 => [ 10, 20, 30 ] })
    get root_path
    outside = page.at_css("body").dup.tap { it.at_css("[data-section=routes]").remove }.text
    expect([ page.css("[data-route='9001'] [data-figure]").size, outside.scan(/\d+\.\d%/) ]).to eq([ 1, [] ])
  end
end
