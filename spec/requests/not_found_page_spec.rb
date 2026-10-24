require "rails_helper"

RSpec.describe "Not-found page", type: :request do
  def not_found_file = Rails.public_path.join("404.html")

  def not_found_page = Nokogiri::HTML5(not_found_file.read)

  describe "關掉除錯頁時（跟正式站一樣）" do
    # The test environment shows Rails' debug page for a missing route; with
    # it off, ActionDispatch::PublicExceptions answers with public/404.html.
    around do |example|
      env_config = Rails.application.env_config
      detailed = env_config["action_dispatch.show_detailed_exceptions"]
      env_config["action_dispatch.show_detailed_exceptions"] = false
      example.run
    ensure
      env_config["action_dispatch.show_detailed_exceptions"] = detailed
    end

    it "不存在的網址回 404，內容是 public/404.html" do
      get "/no-such-page"
      expect([ response.status, response.body ]).to eq([ 404, not_found_file.read ])
    end
  end

  it "title 與牌面都帶著 locale 檔的站名，robots meta 是 noindex, nofollow" do
    name = I18n.t("site.name")
    expect([ not_found_page.title.include?(name), not_found_page.at_css("body").text.include?(name), not_found_page.at_css("meta[name=robots]")&.[]("content") ])
      .to eq([ true, true, "noindex, nofollow" ])
  end
end
