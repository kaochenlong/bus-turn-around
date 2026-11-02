# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardListComponent, type: :component do
  let(:november) { Date.new(2026, 11, 1) }

  def coverage(weekdays: 21, holidays: 9, calendar_weekdays: 21, missing: [])
    { "calendar_weekdays" => calendar_weekdays, "calendar_holidays" => 9, "loaded_weekdays" => weekdays, "loaded_holidays" => holidays, "missing" => missing }
  end

  def missing(from, to) = { "from" => from, "to" => to, "day_type" => "weekday", "reason" => "原始檔不齊" }

  def card(month: november, version: 1, pdf_bytes: 2_450_000, revision_reason: nil, **coverage_options)
    build(:route_card, route_id: 15373, month:, version:, pdf_bytes:, revision_reason:, coverage: coverage(**coverage_options))
  end

  def show(*route_cards, first_to_print: november)
    render_inline(described_class.new(route_name: "中山幹線", route_cards:, first_to_print:))
  end

  def row(month = "2026-11") = page.find("[data-card-month='#{month}']")

  def hrefs(month = "2026-11") = row(month).all("a").map { it[:href] }

  it "標題是路線名" do
    show(card)
    expect(page.find("h1").text).to eq("中山幹線")
  end

  it "規格的一份已印：21 個平日、9 個假日，少 11-05，連到這個月的 PDF" do
    show(card(missing: [ missing("2026-11-05", "2026-11-05") ]))
    expect([ row.text, hrefs ]).to match([ a_string_including("2026 年 11 月", "21 個平日、9 個假日", "少 11-05"), [ "/routes/15373/cards/2026-11.pdf" ] ])
  end

  it "新到舊，跨年也對" do
    show(card(month: Date.new(2026, 12, 1)), card, card(month: Date.new(2027, 1, 1)))
    expect(page.all("[data-card-month]").map { it["data-card-month"] }).to eq(%w[2027-01 2026-12 2026-11])
  end

  it "連結上寫大小：2,450,000 bytes 是 2.5 MB" do
    show(card(pdf_bytes: 2_450_000))
    expect(row.find("a").text).to include("2.5 MB")
  end

  it "不到 1 MB 也寫得出來：900,000 bytes 是 0.9 MB" do
    show(card(pdf_bytes: 900_000))
    expect(row.find("a").text).to include("0.9 MB")
  end

  describe "少的日子" do
    it "沒有少：不寫少" do
      show(card)
      expect(row.text).not_to include("少 ")
    end

    it "連續幾天寫成一段" do
      show(card(missing: [ missing("2026-11-05", "2026-11-07") ]))
      expect(row.text).to include("少 11-05 到 11-07")
    end

    it "好幾段用頓號分開" do
      show(card(missing: [ missing("2026-11-05", "2026-11-05"), missing("2026-11-10", "2026-11-11") ]))
      expect(row.text).to include("少 11-05、11-10 到 11-11")
    end
  end

  describe "部分月份" do
    it "平日不到九成：標出來" do
      show(card(weekdays: 18, calendar_weekdays: 21))
      expect(row).to have_css("[data-partial-month]")
    end

    it "平日夠：不標" do
      show(card(weekdays: 20, calendar_weekdays: 21))
      expect(row).to have_no_css("[data-partial-month]")
    end
  end

  describe "更正過的月份" do
    before { show(card(version: 1, pdf_bytes: 1_000_000), card(version: 2, revision_reason: "資料重算"), card(version: 3, revision_reason: "定義改錯")) }

    it "規格的更正過：第一個連結是不帶版本的最新版，其他連結是每個舊版，新到舊" do
      expect(hrefs).to eq([ "/routes/15373/cards/2026-11.pdf", "/routes/15373/cards/2026-11.pdf?version=2", "/routes/15373/cards/2026-11.pdf?version=1" ])
    end

    it "只有一列：舊版不是另一個月份" do
      expect(page.all("[data-card-month]").size).to eq(1)
    end

    it "最新版的原因寫出來" do
      expect(row.find("[data-revision-reason]").text).to include("定義改錯")
    end

    it "舊版有自己的原因也寫出來，第一版沒有" do
      expect(row.all("[data-earlier-version]").map(&:text)).to match([ a_string_including("v2", "資料重算"), a_string_including("v1") ])
    end

    it "舊版的連結上也寫大小" do
      expect(row.all("[data-earlier-version]").last.text).to include("1.0 MB")
    end
  end

  it "沒有更正過：沒有原因，也沒有舊版" do
    show(card)
    expect([ row.has_css?("[data-revision-reason]"), row.has_css?("[data-earlier-version]") ]).to eq([ false, false ])
  end

  describe "還沒有檔案" do
    it "規格的例子：第一份是 2026 年 11 月，12 月初印出來" do
      show(first_to_print: november)
      expect(page.find("[data-first-month]").text).to include("2026 年 11 月", "12 月初")
    end

    it "跨年：第一份是 2026 年 12 月，1 月初印出來" do
      show(first_to_print: Date.new(2026, 12, 1))
      expect(page.find("[data-first-month]").text).to include("2026 年 12 月", "1 月初")
    end

    it "有檔案就沒有這一句" do
      show(card)
      expect(page).to have_no_css("[data-first-month]")
    end
  end
end
