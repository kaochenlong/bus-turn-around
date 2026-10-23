require "rails_helper"

RSpec.describe "Pages", type: :request do
  def store_days(*days)
    days.each do |day|
      create(:route_day, day: Date.iso8601(day))
    end
  end

  def page = response.parsed_body

  it "首頁回 200，區塊依序是 hero、路線清單、資料限制、資料來源" do
    get root_path
    expect([ response.status, page.css("[data-section]").map { it["data-section"] } ]).to eq([ 200, %w[hero routes limitations sources] ])
  end

  it "站名在 body 的文字裡只出現一次，就在網站名稱列裡" do
    get root_path
    name = I18n.t("site.name")
    expect([ page.at_css("body").text.scan(name).size, page.at_css("[data-site-bar]")&.text&.include?(name) ]).to eq([ 1, true ])
  end

  it "9001 存了 2026-10-20 時，不跑任何 script 拿到的 HTML 已經有插圖、9001 的最新一天、四條資料限制與三個資料集連結" do
    store_days("2026-10-20")
    get root_path
    selectors = [ "[data-section=hero] picture", "[data-route='9001'][data-latest-day='2026-10-20']",
                  "[data-section=limitations] li", "[data-section=sources] a[href]" ]
    expect(selectors.map { page.css(it).size }).to eq([ 1, 1, 4, 3 ])
  end

  it "照設定的順序：15373 沒有資料、不是連結，接著是連到路線頁的 9001" do
    store_days("2026-10-19", "2026-10-20")
    get root_path
    expect(page.css("[data-route]").map { [ it["data-route"], it.key?("data-no-data"), it["href"] ] })
      .to eq([ [ "15373", true, nil ], [ "9001", false, "/routes/9001" ] ])
  end

  it "9001 的卡上是測試幹線、9001、甲站－戊站與 2026-10-20（二）" do
    store_days("2026-10-19", "2026-10-20")
    get root_path
    expect(page.at_css("[data-route='9001']")&.text).to include("測試幹線", "9001", "甲站－戊站", "2026-10-20（二）")
  end
end
