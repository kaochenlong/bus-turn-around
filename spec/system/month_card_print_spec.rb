require "rails_helper"
require "base64"

# Printing a month card in the browser: under the print styles the page carries its
# own attribution and nothing of the site's, and the browser's own print-to-PDF uses
# the page size the page asks for.
RSpec.describe "月卡的列印", :js, type: :system do
  let(:route_name) { "測試幹線" }

  before do
    create(:route_day, day: Date.new(2026, 10, 19), route_name:, rest_windows_loaded: true, published_schedule_day: Date.new(2026, 10, 19))
    create(:route_card)
    visit route_card_path(9001, "2026-10")
    find("main[data-month-card]")
  end

  def browser = page.driver.browser

  # The browser is shared with the other examples, so the emulation is cleared afterwards.
  def under_print_styles(script)
    browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    page.evaluate_script(script)
  ensure
    browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
  end

  # "none" when the first element the selector matches, or an ancestor, is not displayed.
  def display_of(selector) = <<~JS
    (() => {
      for (let node = document.querySelector(#{selector.to_json}); node; node = node.parentElement) {
        if (getComputedStyle(node).display === "none") return "none"
      }
      return "shown"
    })()
  JS

  describe "印的時候" do
    it "名稱列不顯示" do
      expect(under_print_styles(display_of("[data-site-bar]"))).to eq("none")
    end

    it "layout 的顯名聲明不顯示" do
      expect(under_print_styles(display_of("footer[data-attribution]"))).to eq("none")
    end

    it "卡片自己的顯名聲明顯示" do
      expect(under_print_styles(display_of("[data-card-section='attribution']"))).to eq("shown")
    end

    it "卡片用具名頁" do
      expect(under_print_styles("getComputedStyle(document.querySelector('main[data-month-card]')).page")).to eq("month-card")
    end
  end

  describe "螢幕上" do
    it "名稱列照舊" do
      expect(page.evaluate_script(display_of("[data-site-bar]"))).to eq("shown")
    end

    it "layout 的顯名聲明照舊" do
      expect(page.evaluate_script(display_of("footer[data-attribution]"))).to eq("shown")
    end
  end

  it "用頁面自己要的紙張印：第一頁是 A4 直式" do
    pdf = Base64.decode64(browser.execute_cdp("Page.printToPDF", preferCSSPageSize: true, printBackground: true).fetch("data"))
    width, height = pdf.force_encoding(Encoding::BINARY)[/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/n, 0].scan(/[\d.]+/).last(2).map(&:to_f)
    expect([ width, height ]).to contain_exactly(be_within(1).of(595.28), be_within(1).of(841.89))
  end

  it "直式：寬小於高" do
    pdf = Base64.decode64(browser.execute_cdp("Page.printToPDF", preferCSSPageSize: true).fetch("data"))
    width, height = pdf.force_encoding(Encoding::BINARY)[/MediaBox\s*\[\s*0 0 ([\d.]+) ([\d.]+)/n, 0].scan(/[\d.]+/).last(2).map(&:to_f)
    expect(width).to be < height
  end

  # What the page's own style element gives the browser for the page margin.
  def margin_rules = page.evaluate_script("Array.from(document.querySelector('style[data-month-card-margin]').sheet.cssRules).map((rule) => rule.cssText).join(' ')")

  it "頁邊寫路線、月份與頁碼" do
    expect(margin_rules).to include("測試幹線 路線健檢卡 2026 年 10 月", "counter(page)", "counter(pages)")
  end

  describe "路線名有引號、反斜線與結束標籤" do
    let(:route_name) { 'A"B\\C</style><i data-broken>' }

    it "樣式沒有壞，頁邊照樣寫得出來" do
      expect(margin_rules).to include("路線健檢卡 2026 年 10 月", "counter(pages)")
    end

    it "頁面沒有被插進別的標籤" do
      expect(page.evaluate_script("document.querySelectorAll('[data-broken]').length")).to eq(0)
    end
  end
end
