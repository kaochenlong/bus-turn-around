require "rails_helper"

RSpec.describe "Rest command in the console", :js, type: :system do
  # The hint and the rule, worded as in the spec, so the lines can be told
  # apart from anything else the page writes to the console.
  def hint = "輸入 休息() 試試看"

  def rule = "駕駛連續開車 4 小時，至少要休息 30 分鐘（汽車運輸業管理規則第 19 條之 2）"

  # Records the page's console.log calls in window.consoleLines, each call's
  # arguments joined by spaces, and passes them on to the console.
  def console_recorder = <<~JS
    window.consoleLines = []
    const originalLog = console.log.bind(console)
    console.log = (...args) => { window.consoleLines.push(args.join(" ")); originalLog(...args) }
  JS

  # Visits `path` with the recorder installed before any of the page's own
  # scripts run. A Turbo visit keeps the document, so the record goes on.
  def visit_recording_console(path)
    browser = page.driver.browser
    script = browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: console_recorder)["identifier"]
    visit path
  ensure
    browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: script) if script
  end

  def console_lines = page.evaluate_script("window.consoleLines")

  it "完整載入首頁，console 收到一次提示，window.休息 是函式" do
    visit_recording_console root_path
    expect([ console_lines.count(hint), page.evaluate_script("typeof window.休息") ]).to eq([ 1, "function" ])
  end

  it "呼叫 休息() 回傳 undefined，console 收到第 19 條之 2 的休息規則" do
    visit_recording_console root_path
    expect([ page.evaluate_script("休息()"), console_lines.last ]).to eq([ nil, rule ])
  end

  it "開路線頁之後，用網站名稱列的連結換到首頁，提示仍然只有一次" do
    visit_recording_console route_path(9001)
    find("[data-site-bar] a").click
    find("[data-section=hero]")
    expect(console_lines.count(hint)).to eq(1)
  end
end
