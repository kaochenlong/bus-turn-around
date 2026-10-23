require "rails_helper"

RSpec.describe "Site layout", type: :request do
  def page = response.parsed_body

  def title = page.at_css("title").text

  def footers = page.css('footer[data-attribution][data-license="OGDL-Taiwan-1.0"]')

  # The footer itself and everything inside it.
  def sections_in_footer = page.css("footer[data-attribution][data-section], footer[data-attribution] [data-section]")

  def body_classes = page.at_css("body")["class"].to_s.split

  def site_bars = page.css("[data-site-bar]")

  # The bar itself and everything inside it.
  def sections_in_site_bar = page.css("[data-site-bar][data-section], [data-site-bar] [data-section]")

  it "首頁的 body 第一個元素是唯一一條網站名稱列，在 main 之前，連回 / 、文字是站名" do
    get root_path
    link = site_bars.first&.at_css("a")
    expect([ site_bars.size, page.at_css("body").element_children.first == site_bars.first, link&.[]("href"), link&.text&.squish ])
      .to eq([ 1, true, "/", I18n.t("site.name") ])
  end

  it "9001 還沒有任何資料時，路線頁回 200，恰好一條網站名稱列，列本身與裡面都沒有 data-section" do
    get route_path(9001)
    expect([ response.status, site_bars.size, sections_in_site_bar.size ]).to eq([ 200, 1, 0 ])
  end

  it "首頁沒有設自己的 title，title 與 application-name 都是站名" do
    get root_path
    expect([ title, page.at_css("meta[name=application-name]")["content"] ]).to eq([ I18n.t("site.name") ] * 2)
  end

  it "9001 還沒有任何資料時，路線頁回 200，title 是站名" do
    get route_path(9001)
    expect([ response.status, title ]).to eq([ 200, I18n.t("site.name") ])
  end

  it "首頁恰好有一個顯名聲明 footer" do
    get root_path
    expect(footers.size).to eq(1)
  end

  it "頁尾有一行是設定的底圖顯名：測試環境是測試用空白底圖" do
    get root_path
    expect(page.css("footer[data-attribution] p").map { it.text.strip }).to include("測試用空白底圖")
  end

  it "9001 還沒有任何資料時，路線頁回 200，恰好一個顯名聲明 footer，footer 本身與裡面都沒有 data-section" do
    get route_path(9001)
    expect([ response.status, footers.size, sections_in_footer.size ]).to eq([ 200, 1, 0 ])
  end

  it "路線頁的 body 帶 slate-50 底色，顯名聲明 footer 跟著同一個底色；首頁的 body 沒有底色" do
    get route_path(9001)
    route_classes = body_classes
    get root_path
    expect([ route_classes.include?("bg-slate-50"), body_classes.include?("bg-slate-50") ]).to eq([ true, false ])
  end
end
