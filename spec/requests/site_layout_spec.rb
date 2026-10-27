require "rails_helper"

RSpec.describe "Site layout", type: :request do
  def page = response.parsed_body

  def title = page.at_css("title").text

  # The og:title, twitter:title, description, og:description and
  # twitter:description metas.
  def share_metas
    [ "meta[property='og:title']", "meta[name='twitter:title']", "meta[name='description']", "meta[property='og:description']", "meta[name='twitter:description']" ]
      .map { page.at_css(it)["content"] }
  end

  def footers = page.css('footer[data-attribution][data-license="OGDL-Taiwan-1.0"]')

  # The three quoted paragraphs of the 授權 section of docs/data-sources.md,
  # taken the way spec/analysis/card_spec.rb takes them for the health card.
  def statement_in_docs
    licence = Rails.root.join("docs/data-sources.md").read[/^### 授權\n(.*?)(?=^#)/m, 1]
    licence.lines.grep(/\A> /).map { it.delete_prefix("> ").chomp }
  end

  # The footer itself and everything inside it.
  def sections_in_footer = page.css("footer[data-attribution][data-section], footer[data-attribution] [data-section]")

  def body_classes = page.at_css("body")["class"].to_s.split

  def site_bars = page.css("[data-site-bar]")

  # The bar itself and everything inside it.
  def sections_in_site_bar = page.css("[data-site-bar][data-section], [data-site-bar] [data-section]")

  # Every link of the bar: where it points, its text and its aria-current.
  def bar_links = site_bars.first.css("a").map { [ it["href"], it.text.squish, it["aria-current"] ] }

  # The bar's own wording, read from its file: sidecar translations are not in
  # the global I18n backend.
  def bar_wording(key) = YAML.load_file(Rails.root.join("app/components/site_bar_component.yml"), aliases: true).dig("tw", key)

  it "首頁的名稱列恰好三個連結：站名連回 /，GitHub 連到 repo，關於這個網站連到文章" do
    get root_path
    expect(bar_links.map(&:first)).to eq([ "/", SiteBarComponent::REPOSITORY_URL, SiteBarComponent::ABOUT_URL ])
  end

  it "規格的路線頁的名稱列：五個連結，班表連到該路線的班表頁、當天調度連到當天調度頁，都沒有 aria-current；GitHub 連到 repo；關於的文字照舊是關於這個網站；9001 沒有資料也一樣" do
    get route_path(9001)
    expect(bar_links).to eq([ [ "/", I18n.t("site.name"), nil ], [ "/routes/9001/timetable", bar_wording("timetable"), nil ], [ "/routes/9001/dispatch", bar_wording("day_dispatch"), nil ],
                              [ SiteBarComponent::REPOSITORY_URL, bar_wording("repository"), nil ], [ SiteBarComponent::ABOUT_URL, bar_wording("about_lead") + bar_wording("about_rest"), nil ] ])
  end

  it "規格的班表頁的名稱列：五個連結，班表連到班表頁本身、帶 aria-current=page，當天調度沒有" do
    get route_timetable_path(9001)
    expect(bar_links.map { [ it[0], it[2] ] }).to eq([ [ "/", nil ], [ "/routes/9001/timetable", "page" ], [ "/routes/9001/dispatch", nil ], [ SiteBarComponent::REPOSITORY_URL, nil ], [ SiteBarComponent::ABOUT_URL, nil ] ])
  end

  it "規格的當天調度頁的名稱列：五個連結，當天調度連到當天調度頁本身、帶 aria-current=page，班表沒有" do
    get route_dispatch_path(9001)
    expect(bar_links.map { [ it[0], it[2] ] }).to eq([ [ "/", nil ], [ "/routes/9001/timetable", nil ], [ "/routes/9001/dispatch", "page" ], [ SiteBarComponent::REPOSITORY_URL, nil ], [ SiteBarComponent::ABOUT_URL, nil ] ])
  end

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

  it "首頁沒有設自己的 title 與描述：title、og:title、twitter:title 是站名，三個 description 是站的描述" do
    get root_path
    expect([ title, *share_metas ]).to eq([ I18n.t("site.name") ] * 3 + [ I18n.t("site.description") ] * 3)
  end

  it "9001 還沒有任何資料時，路線頁的六個標籤跟首頁一樣是站名與站的描述" do
    get route_path(9001)
    expect([ title, *share_metas ]).to eq([ I18n.t("site.name") ] * 3 + [ I18n.t("site.description") ] * 3)
  end

  it "首頁恰好有一個顯名聲明 footer" do
    get root_path
    expect(footers.size).to eq(1)
  end

  it "首頁頁尾的前三段依序逐字等於 docs/data-sources.md 授權那一節的三段顯名聲明" do
    get root_path
    expect(page.css("footer[data-attribution] p").first(3).map { it.text.strip }).to eq(statement_in_docs)
  end

  it "頁尾有一行是設定的底圖顯名：測試環境是測試用空白底圖" do
    get root_path
    expect(page.css("footer[data-attribution] p").map { it.text.strip }).to include("測試用空白底圖")
  end

  it "首頁與路線頁的頁尾都恰好有一行報告書的顯名，書名跟查核分數設定裡最新一期的報告書相同" do
    title = RoutePage::DepotInspections.current.title
    lines = [ root_path, route_path(9001) ].map { get(it).then { page.css("footer[data-attribution] p").count { it.text.include?(title) } } }
    expect(lines).to eq([ 1, 1 ])
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
