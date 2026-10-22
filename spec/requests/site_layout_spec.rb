require "rails_helper"

RSpec.describe "Site layout", type: :request do
  def page = response.parsed_body

  def title = page.at_css("title").text

  def footers = page.css('footer[data-attribution][data-license="OGDL-Taiwan-1.0"]')

  # The footer itself and everything inside it.
  def sections_in_footer = page.css("footer[data-attribution][data-section], footer[data-attribution] [data-section]")

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

  it "9001 還沒有任何資料時，路線頁回 200，恰好一個顯名聲明 footer，footer 本身與裡面都沒有 data-section" do
    get route_path(9001)
    expect([ response.status, footers.size, sections_in_footer.size ]).to eq([ 200, 1, 0 ])
  end
end
