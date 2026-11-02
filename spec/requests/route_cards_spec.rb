require "rails_helper"
require_relative "../support/duckdb"

RSpec.describe "RouteCards", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:month_card) { css_select("main[data-month-card]").sole }

  def store(day, **attributes)
    create(:route_day, day: Date.iso8601(day), rest_windows_loaded: true, published_schedule_day: Date.iso8601(day), **attributes)
  end

  def section_names = css_select("[data-card-section]").map { it["data-card-section"] }

  describe "有卡的月份" do
    before do
      store("2026-10-19", route_name: "測試幹線")
      create(:route_card)
    end

    it "回 200，九個區塊照順序各一次" do
      get route_card_path(9001, "2026-10")
      expect([ response.status, section_names ]).to eq([ 200, %w[summary layovers driving schedule cycles run-times buffer history attribution] ])
    end

    it "文件標題是路線名、健檢卡、年月，再接網站名稱" do
      get route_card_path(9001, "2026-10")
      expect(css_select("title").text).to eq("測試幹線 健檢卡 2026 年 10 月｜#{I18n.t('site.name')}")
    end

    it "不給搜尋引擎收" do
      get route_card_path(9001, "2026-10")
      expect(css_select("meta[name=robots]").sole["content"]).to eq("noindex")
    end

    it "月份個位數的文件標題不補零" do
      create(:route_card, month: Date.new(2026, 9, 1))
      get route_card_path(9001, "2026-09")
      expect(css_select("title").text).to include("2026 年 9 月")
    end

    it "讀版本最大的那一列" do
      create(:route_card, version: 2, coverage: { "calendar_weekdays" => 20, "calendar_holidays" => 11, "loaded_weekdays" => 19, "loaded_holidays" => 9, "missing" => [] })
      get route_card_path(9001, "2026-10")
      expect(month_card.text).to include("涵蓋 19 個平日")
    end

    describe "印製時讀的 meta" do
      def meta(name) = css_select("meta[name=#{name}]").sole["content"]

      it "turnaround-card 是路線、月份與版本：9001/2026-10/1" do
        get route_card_path(9001, "2026-10")
        expect(meta("turnaround-card")).to eq("9001/2026-10/1")
      end

      it "版本是這一頁讀的那一版：9001/2026-10/2" do
        create(:route_card, version: 2)
        get route_card_path(9001, "2026-10")
        expect(meta("turnaround-card")).to eq("9001/2026-10/2")
      end

      it "turnaround-program-version 是跑這個程式的版本" do
        allow(ProgramVersion).to receive(:current).and_return("abc1234")
        get route_card_path(9001, "2026-10")
        expect(meta("turnaround-program-version")).to eq("abc1234")
      end

      it "turnaround-card-summary 是這個月的摘要：一個平日，這天沒有視窗" do
        get route_card_path(9001, "2026-10")
        expect(JSON.parse(meta("turnaround-card-summary"))).to include("weekdays" => 1, "four_hours_share" => nil, "six_hours_share" => nil)
      end
    end

    it "名稱列跟其他路線頁一樣連到這條路線的班表" do
      get route_card_path(9001, "2026-10")
      expect(css_select("[data-site-bar] [data-timetable-link]").sole["href"]).to start_with(route_timetable_path(9001))
    end
  end

  # Whether a request reads the table of the bytes.
  def read_pdf_bytes?
    queries = []
    ActiveSupport::Notifications.subscribed(->(*, payload) { queries << payload[:sql] }, "sql.active_record") { yield }
    queries.any? { it.include?("route_card_pdfs") }
  end

  describe "月份清單" do
    let(:coverage) { { "calendar_weekdays" => 21, "calendar_holidays" => 9, "loaded_weekdays" => 21, "loaded_holidays" => 9, "missing" => [ { "from" => "2026-11-05", "to" => "2026-11-05", "day_type" => "weekday", "reason" => "原始檔不齊" } ] } }

    def month_rows = css_select("[data-card-month]")

    it "規格的一份已印：一列，帶涵蓋，連到 PDF" do
      create(:route_card, :printed, month: Date.new(2026, 11, 1), coverage:)
      get "/routes/9001/cards"
      expect([ response.status, month_rows.size, month_rows.first.text.squish, month_rows.first.at_css("a")["href"] ]).to match([ 200, 1, a_string_including("21 個平日、9 個假日", "少 11-05"), "/routes/9001/cards/2026-11.pdf" ])
    end

    it "規格的更正過：連到最新版與舊版，寫原因" do
      create(:route_card, :printed, month: Date.new(2026, 11, 1), coverage:)
      create(:route_card, :printed, month: Date.new(2026, 11, 1), coverage:, version: 2, revision_reason: "資料重算")
      get "/routes/9001/cards"
      expect([ month_rows.first.css("a").map { it["href"] }, month_rows.first.text.include?("資料重算") ]).to eq([ [ "/routes/9001/cards/2026-11.pdf", "/routes/9001/cards/2026-11.pdf?version=1" ], true ])
    end

    it "規格的沒有 PDF 的列：不出現" do
      create(:route_card, month: Date.new(2026, 12, 1))
      get "/routes/9001/cards"
      expect(month_rows).to be_empty
    end

    it "規格的還沒有檔案：2026-11-02、第一個月 2026-11，說第一份是 2026 年 11 月，12 月初" do
      allow(CardMonths).to receive(:from_config).and_return(CardMonths.new(first_month: Date.new(2026, 11, 1)))
      travel_to(Time.zone.parse("2026-11-02 12:00")) { get "/routes/9001/cards" }
      expect(css_select("[data-first-month]").sole.text).to include("2026 年 11 月", "12 月初")
    end

    it "第一個月已經過了：說第一份是上個月，月初印" do
      allow(CardMonths).to receive(:from_config).and_return(CardMonths.new(first_month: Date.new(2026, 11, 1)))
      travel_to(Time.zone.parse("2027-02-15 12:00")) { get "/routes/9001/cards" }
      expect(css_select("[data-first-month]").sole.text).to include("2027 年 1 月", "2 月初")
    end

    it "規格的成員路線：/routes/19108/cards 回 404" do
      get "/routes/19108/cards"
      expect(response).to have_http_status(:not_found)
    end

    it "路線 Id 不是數字：回 404" do
      get "/routes/abc/cards"
      expect(response).to have_http_status(:not_found)
    end

    it "不讀位元組" do
      create(:route_card, :printed, month: Date.new(2026, 11, 1), coverage:)
      expect(read_pdf_bytes? { get "/routes/9001/cards" }).to be(false)
    end

    it "別條路線的月份不列" do
      create(:route_card, :printed, route_id: 9100, month: Date.new(2026, 11, 1), coverage:)
      get "/routes/9001/cards"
      expect(month_rows).to be_empty
    end

    it "文件標題是路線名，取最新一天的名字，再接網站名稱" do
      create(:route_day, day: Date.new(2026, 10, 19), route_name: "舊名")
      create(:route_day, day: Date.new(2026, 10, 20), route_name: "測試幹線")
      get "/routes/9001/cards"
      expect(css_select("title").text).to eq("測試幹線 健檢卡｜#{I18n.t('site.name')}")
    end

    it "這條路線還沒有資料：標題用路線 Id" do
      get "/routes/9001/cards"
      expect(css_select("title").text).to eq("9001 健檢卡｜#{I18n.t('site.name')}")
    end
  end

  describe "下載 PDF" do
    let(:october) { Date.new(2026, 10, 1) }

    def printed(version: 1, pdf: "第 #{version} 版") = create(:route_card, :printed, month: october, version:, pdf:)

    it "規格的最新版：內容是 v2，檔名是路線與月份" do
      printed(version: 1)
      printed(version: 2)
      get "/routes/9001/cards/2026-10.pdf"
      expect([ response.body, response.headers["Content-Disposition"] ]).to match([ "第 2 版".b, a_string_including("attachment", 'filename="turnaround-9001-2026-10.pdf"') ])
    end

    it "規格的舊版：version=1 的內容是 v1" do
      printed(version: 1)
      printed(version: 2)
      get "/routes/9001/cards/2026-10.pdf", params: { version: 1 }
      expect(response.body).to eq("第 1 版".b)
    end

    it "Content-Type 是 application/pdf" do
      printed
      get "/routes/9001/cards/2026-10.pdf"
      expect(response.media_type).to eq("application/pdf")
    end

    it "ETag 是這一版的 SHA-256" do
      card = printed
      get "/routes/9001/cards/2026-10.pdf"
      expect(response.headers["ETag"]).to eq(%("#{card.reload.pdf_sha256}"))
    end

    it "公開快取一天" do
      printed
      get "/routes/9001/cards/2026-10.pdf"
      expect(response.headers["Cache-Control"]).to include("public", "max-age=86400")
    end

    it "最新一版還沒印好：給最新的已印版本" do
      printed(version: 1)
      create(:route_card, month: october, version: 2)
      get "/routes/9001/cards/2026-10.pdf"
      expect(response.body).to eq("第 1 版".b)
    end

    it "規格的沒有變：If-None-Match 是這一版的 SHA-256，回 304，不讀位元組" do
      card = printed
      read = read_pdf_bytes? { get "/routes/9001/cards/2026-10.pdf", headers: { "If-None-Match" => %("#{card.reload.pdf_sha256}") } }
      expect([ response.status, read, response.body ]).to eq([ 304, false, "" ])
    end

    it "If-None-Match 是別的值：回 200" do
      printed
      get "/routes/9001/cards/2026-10.pdf", headers: { "If-None-Match" => '"別的"' }
      expect(response).to have_http_status(:ok)
    end

    it "更正之後舊的 SHA-256 不算沒變：回新的那一版" do
      first = printed(version: 1)
      printed(version: 2)
      get "/routes/9001/cards/2026-10.pdf", headers: { "If-None-Match" => %("#{first.reload.pdf_sha256}") }
      expect([ response.status, response.body ]).to eq([ 200, "第 2 版".b ])
    end

    describe "404" do
      it "規格的還沒印：有列沒有 PDF" do
        create(:route_card, month: october)
        get "/routes/9001/cards/2026-10.pdf"
        expect(response).to have_http_status(:not_found)
      end

      it "這個月沒有列" do
        get "/routes/9001/cards/2026-10.pdf"
        expect(response).to have_http_status(:not_found)
      end

      it "指定的版本沒印好" do
        printed(version: 1)
        create(:route_card, month: october, version: 2)
        get "/routes/9001/cards/2026-10.pdf", params: { version: 2 }
        expect(response).to have_http_status(:not_found)
      end

      it "指定的版本不存在" do
        printed(version: 1)
        get "/routes/9001/cards/2026-10.pdf", params: { version: 9 }
        expect(response).to have_http_status(:not_found)
      end

      [ "abc", "", "1.5", "-1" ].each do |version|
        it "版本不是數字（#{version.inspect}）" do
          printed(version: 1)
          get "/routes/9001/cards/2026-10.pdf", params: { version: }
          expect(response).to have_http_status(:not_found)
        end
      end

      { "不是頁面路線" => "/routes/9100/cards/2026-10.pdf",
        "路線 Id 不是數字" => "/routes/abc/cards/2026-10.pdf",
        "沒有 13 月" => "/routes/9001/cards/2026-13.pdf",
        "月份不是日期" => "/routes/9001/cards/latest.pdf" }.each do |situation, path|
        it situation do
          printed(version: 1)
          get path
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  it "規格的印過的月卡頁：開頁面不讀位元組，連舊月份的列也一樣" do
    create(:route_card, :printed, month: Date.new(2026, 9, 1))
    create(:route_card, :printed)
    expect(read_pdf_bytes? { get route_card_path(9001, "2026-10") }).to be(false)
  end

  describe "404" do
    before { create(:route_card) }

    { "這個月沒有卡" => "/routes/9001/cards/2026-11",
      "不是頁面路線" => "/routes/9100/cards/2026-10",
      "成員路線沒有自己的頁" => "/routes/19108/cards/2026-10",
      "路線 Id 不是數字" => "/routes/abc/cards/2026-10",
      "沒有 13 月" => "/routes/9001/cards/2026-13",
      "沒有 0 月" => "/routes/9001/cards/2026-00",
      "月份沒補零" => "/routes/9001/cards/2026-1",
      "月份帶日" => "/routes/9001/cards/2026-10-01",
      "月份不是日期" => "/routes/9001/cards/latest" }.each do |situation, path|
      it situation do
        get path
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "還沒重算的日子" do
    before { create(:route_card) }

    def notice = css_select("main[data-month-card] > [data-card-incomplete]")

    it "有一天沒有視窗：最上面說數字不完整" do
      store("2026-10-19", rest_windows_loaded: false)
      get route_card_path(9001, "2026-10")
      expect(notice.size).to eq(1)
    end

    it "有一天沒有公告：最上面說數字不完整" do
      store("2026-10-19", published_schedule_day: nil)
      get route_card_path(9001, "2026-10")
      expect(notice.size).to eq(1)
    end

    it "提醒在第一個區塊之前" do
      store("2026-10-19", rest_windows_loaded: false)
      get route_card_path(9001, "2026-10")
      expect(month_card.element_children.first["data-card-incomplete"]).not_to be_nil
    end

    it "都重算過：沒有提醒" do
      store("2026-10-19")
      get route_card_path(9001, "2026-10")
      expect(notice).to be_empty
    end
  end

  it "這個月一天都沒有存：頁面照樣開" do
    create(:route_card)
    get route_card_path(9001, "2026-10")
    expect(response).to have_http_status(:ok)
  end

  describe "用真的 fixture 日載入", :duckdb do
    before do
      RouteDayLoader.new(route_id: 9001, day: Date.new(2026, 10, 19), data_root: DuckdbHelpers::FIXTURE_DATA, duckdb: "duckdb", out: StringIO.new).call
      create(:route_card)
      get route_card_path(9001, "2026-10")
    end

    it "沒有車牌，也沒有對合規下判定的字" do
      expect(month_card.text).not_to match(/TEST-|不合規|違規/)
    end

    it "折返點設施、調度站、捷運與車上人數都不放" do
      expect(month_card.text).not_to match(/公廁|調度站|捷運|車上人數/)
    end

    it "沒有獨立的資料限制區塊" do
      expect(section_names).not_to include("limits")
    end

    it "頁面照樣有數字：回 200" do
      expect(response).to have_http_status(:ok)
    end
  end
end
