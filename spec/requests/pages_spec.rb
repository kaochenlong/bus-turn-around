require "rails_helper"

RSpec.describe "Pages", type: :request do
  def store_days(*days)
    days.each do |day|
      create(:route_day, day: Date.iso8601(day))
    end
  end

  def page = response.parsed_body

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
end
