require "rails_helper"

# The day record of the day dispatch page: exported as two CSV files and
# printed in place of the view, all made in the browser from the day it
# keeps, sending nothing about the day to the server.
RSpec.describe "當天紀錄", :js, type: :system do
  # A complete trip of the day starting at `start` that runs for `minutes`.
  def add_trip(route_day, start, minutes, go_back)
    start_time = Time.zone.parse("#{route_day.day} #{start}")
    route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + minutes.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  # Two departures from 甲站 in the 06 hour running 50 minutes and two from
  # 乙站 in the 08 hour running 45. Laid out with 15 rest minutes they take
  # two vehicles: vehicle 1 runs 06:00–06:50 and 08:00–08:45, vehicle 2
  # 06:30–07:20 and 08:30–09:15.
  before do
    route_day = create(:route_day, day: Date.new(2026, 10, 19))
    route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 5, stop_name: "乙站" } ])
    %w[06:00 06:30].each { add_trip(route_day, it, 50, 0) }
    %w[08:00 08:30].each { add_trip(route_day, it, 45, 1) }
  end

  # The browser is shared with the other examples: each keeps its own days.
  after { page.execute_script("window.localStorage.clear()") if page.current_url.start_with?("http") }

  # The words of a component, with the values filled in.
  def component_text(component, *keys, **values)
    format(YAML.load_file(Rails.root.join("app/components/#{component}.yml"), aliases: true).dig("tw", *keys.map(&:to_s)), **values)
  end

  def day_text(*keys, **values) = component_text("day_dispatch_component", *keys, **values)

  # Starts today's plan of 9001, laid out from weekdays, and waits for the day.
  def start_day
    visit "/routes/9001/dispatch?type=weekday"
    find("[data-day-start] [data-plan-summary] [data-slot=vehicles]", text: /\d/)
    click_button component_text("day_start_component", :start)
    find("[data-day-dispatch] [data-slot=date]", text: /\S/)
  end

  # Today's Taipei date, as the files are named by it.
  def today = Time.zone.today.iso8601

  # From now on every download link clicked is kept, with its file name, its
  # address and its text as it reads, and the download itself is stopped.
  # Reading a blob address is no request to the server.
  def catch_downloads = page.execute_script(<<~JS)
    window.downloads = []
    document.addEventListener("click", (event) => {
      const link = event.target.closest("a[download]")
      if (!link) return
      event.preventDefault()
      window.downloads.push({ name: link.download, href: link.href, text: fetch(link.href).then((response) => response.text()) })
    }, true)
  JS

  # The downloads so far, as each file's name and whether its address is a blob.
  def downloads = page.evaluate_script("window.downloads.map((download) => [download.name, download.href.startsWith('blob:')])")

  # A download's text, as UTF-8 decoding reads it: without its byte order mark.
  def downloaded_text(index) = page.evaluate_async_script("window.downloads[arguments[0]].text.then(arguments[1])", index)

  # The requests the page has made since it loaded, its resources included.
  def requests_made = page.evaluate_script('performance.getEntriesByType("resource").length')

  describe "匯出" do
    it "規格的匯出不送請求：匯出修改清單的連結帶檔名與 blob: 位址，頁面沒有多送任何請求" do
      start_day.then { catch_downloads }
      made = requests_made
      click_button day_text(:export_changes)
      expect([ downloads, requests_made ]).to eq([ [ [ "day-dispatch-9001-#{today}-changes.csv", true ] ], made ])
    end

    it "兩個匯出按鈕各下載一個檔：修改清單一個、最後的單一個" do
      start_day.then { catch_downloads }
      %i[export_changes export_sheets].each { click_button day_text(it) }
      expect(downloads).to eq(%w[changes sheets].map { [ "day-dispatch-9001-#{today}-#{it}.csv", true ] })
    end

    it "還沒有修改時，匯出的修改清單只有表頭，用的是頁面上的字" do
      start_day.then { catch_downloads }
      click_button day_text(:export_changes)
      expect(downloaded_text(0)).to eq("記下時刻,種類,車,那一趟,換給,時刻,原因,已復原\r\n")
    end

    it "匯出的最後的單一趟一列，方向與起站照頁面上的名字：1 號車 06:00 從甲站發、08:00 從乙站發" do
      start_day.then { catch_downloads }
      click_button day_text(:export_sheets)
      expect(downloaded_text(0).split("\r\n").first(3)).to eq([ "車,方向,起站,發車,到達,到達是記下的,原排,改過發車,原本的發車", "1,去程,甲站,06:00,06:50,否,1,否,06:00", "1,返程,乙站,08:00,08:45,否,1,否,08:00" ])
    end
  end

  # HH:MM as minutes of the day.
  def minutes(time) = time.split(":").map(&:to_i).then { |hour, minute| (hour * 60) + minute }

  def show_end(stop, direction) = click_button(day_text(:end, stop:, direction:)).then { find("[data-end][aria-pressed=true]", text: stop) }

  # The row of the departure listed at `time`.
  def departure_row(time) = find("[data-day-dispatch] tr[data-trip][data-departure='#{minutes(time)}']")

  def give(time, vehicle) = departure_row(time).find("[data-control=vehicle]").select("#{vehicle} 號車")

  def retype(time, typed) = departure_row(time).find("[data-control=departure]").set(typed).send_keys(:tab)

  # Records a vehicle back at the end listed, at a typed time.
  def record_back(vehicle, typed)
    within("[data-day-dispatch] form[data-record]") { select("#{vehicle} 號車", from: day_text(:record, :vehicle)).then { fill_in(day_text(:record, :time), with: typed) } }
    click_button day_text(:record, :submit)
  end

  # Three changes, the last of them undone: vehicle 1 recorded back at 乙站 at
  # 07:00 for traffic, its 08:00 from 乙站 given to vehicle 2, and vehicle 2's
  # 06:30 from 甲站 retyped as 06:35, then undone.
  def make_three_changes
    show_end("乙站", "返程").then { find("[data-record-reason]").set("塞車") }.then { record_back(1, "0700") }
    give("08:00", 2)
    show_end("甲站", "去程").then { retype("06:30", "0635") }.then { click_button day_text(:undo) }
  end

  # The browser's print is announced before it prints; the page draws the
  # record then.
  def before_print = page.execute_script("window.dispatchEvent(new Event('beforeprint'))")

  def browser = page.driver.browser

  # What `script` evaluates to while the browser applies the print styles.
  # The browser is shared with the other examples, so the emulation is
  # cleared afterwards.
  def under_print_styles(script)
    browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    page.evaluate_script(script)
  ensure
    browser.execute_cdp("Emulation.setEmulatedMedia", media: "")
  end

  # Whether the browser's print-to-PDF has a page of that number: asking for a
  # page past the end is an error.
  def printed_page?(number)
    browser.execute_cdp("Page.printToPDF", pageRanges: number.to_s)
    true
  rescue Selenium::WebDriver::Error::WebDriverError
    false
  end

  # A script giving, for each selector, whether the first element it matches
  # is shown: there is one, and it and every ancestor are displayed.
  def shown(selectors) = <<~JS
    (() => {
      const shown = (element) => {
        if (!element) return false
        for (let node = element; node; node = node.parentElement) if (getComputedStyle(node).display === "none") return false
        return true
      }
      return Object.fromEntries(Object.entries(#{selectors.to_json}).map(([name, selector]) => [name, shown(document.querySelector(selector))]))
    })()
  JS

  # A script giving the record's blocks that are shown, in order: the
  # summary, each sheet by its vehicle, the data limitations and the
  # attribution footer.
  def printed_blocks = <<~JS
    [...document.querySelectorAll("[data-record-summary], [data-record-sheets] [data-vehicle], [data-day-record] [data-section=limitations], footer[data-attribution]")]
      .filter((element) => element.checkVisibility())
      .map((element) => element.dataset.vehicle ? `sheet ${element.dataset.vehicle}` : element.matches("[data-record-summary]") ? "summary" : element.matches("footer") ? "footer" : "limitations")
  JS

  # The printed change log's rows, as what each says, its reason and whether
  # it is marked undone; the time it was recorded is the clock's.
  def printed_changes = '[...document.querySelectorAll("[data-slot=record-changes] tr")].map((tr) => [...tr.cells].slice(1).map((cell) => cell.innerText.trim()))'

  # The parts of the view on screen, which are not printed.
  def view_parts = { header: "[data-day-dispatch] > header", figures: "[data-day-dispatch] [data-figure=swaps]", timeline: "[data-day-timeline]", departures: "[data-departures-frame]",
                     form: "[data-day-dispatch] form[data-record]", changes: "[data-day-dispatch] [data-slot=changes]", print: "button[data-print-record]", site_bar: "[data-site-bar]" }

  # The parts of the record, which only print.
  def record_parts = { summary: "[data-record-summary]", sheet: "[data-record-sheets] [data-vehicle]", limitations: "[data-day-record] [data-section=limitations]" }

  # Each printed sheet's line under the form's title and its first departure.
  def sheet_heads = '[...document.querySelectorAll("[data-record-sheets] [data-vehicle]")].map((sheet) => [sheet.querySelector("[data-slot=print-header]").innerText, sheet.querySelector("tbody td[data-departure]").innerText])'

  describe "印出當天紀錄" do
    it "按印出當天紀錄呼叫瀏覽器的列印一次" do
      start_day.then { page.execute_script("window.printCalls = 0; window.print = () => { window.printCalls += 1 }") }
      click_button day_text(:print_record)
      expect(page.evaluate_script("window.printCalls")).to eq(1)
    end

    it "規格的印出來的順序：摘要、1 號車與 2 號車的單各自一頁，最後是資料限制與顯名聲明，一共四頁" do
      start_day.then { make_three_changes }.then { before_print }
      expect([ under_print_styles(printed_blocks), (1..5).map { printed_page?(it) } ]).to eq([ [ "summary", "sheet 1", "sheet 2", "limitations", "footer" ], [ true, true, true, true, false ] ])
    end

    it "規格的摘要列出三筆修改，最後一筆標成已復原" do
      start_day.then { make_three_changes }.then { before_print }
      expect(under_print_styles(printed_changes)).to eq([ [ "1 號車 07:00 回到乙站", "塞車", "" ], [ "08:00 乙站發車那一班改派 2 號車，原本是 1 號車", "", "" ], [ "2 號車 06:30 那一班改成 06:35 發車", "", day_text(:undone) ] ])
    end

    it "印的時候，名稱列與畫面上的頁首、四個數字、時間軸、側欄、表單與按鈕都不印" do
      start_day.then { before_print }
      expect(under_print_styles(shown(view_parts))).to eq(view_parts.keys.index_with(false).stringify_keys)
    end

    it "規格的螢幕上看不到紀錄：兩張單畫好了，但摘要、單子與資料限制都藏著，畫面的頁首、四個數字與時間軸照常" do
      start_day.then { before_print }
      expect([ page.evaluate_script(shown(record_parts.merge(view_parts.slice(:header, :figures, :timeline)))), all("[data-record-sheets] [data-vehicle]", visible: :all).size ])
        .to eq([ { "summary" => false, "sheet" => false, "limitations" => false, "header" => true, "figures" => true, "timeline" => true }, 2 ])
    end

    it "今天還沒開始時，當天紀錄的列印規則不套用：今天的計畫照原本的版面印" do
      visit "/routes/9001/dispatch?type=weekday"
      find("[data-day-start] [data-plan-summary] [data-slot=vehicles]", text: /\d/)
      expect(under_print_styles('["page", "display"].map((name) => getComputedStyle(document.querySelector("main[data-day-dispatch-page]"))[name])')).to eq(%w[auto flex])
    end

    it "還沒有修改時，印出來的修改清單只寫沒有修改，不印表格" do
      start_day.then { before_print }
      expect(under_print_styles(shown(table: "[data-day-record] table", none: "[data-record-changes-none]"))).to eq({ "table" => false, "none" => true })
    end

    it "摘要的四個數字跟畫面上的一樣" do
      start_day.then { make_three_changes }.then { before_print }
      expect(under_print_styles('[...document.querySelectorAll("[data-record-figure]")].map((figure) => figure.innerText)')).to eq(%w[swaps typed waiting shortest].map { find("[data-figure=#{it}]").text })
    end

    it "每台車的休息照車號，附計畫的數字：兩張單都不到 4 小時" do
      start_day.then { before_print }
      expect(page.evaluate_script('[...document.querySelectorAll("[data-slot=record-credits] > li")].map((cell) => [...cell.querySelectorAll("[data-slot]")].map((slot) => slot.textContent))'))
        .to eq([ [ "1 號車", "不到 4 小時", "計畫不到 4 小時" ], [ "2 號車", "不到 4 小時", "計畫不到 4 小時" ] ])
    end

    it "一車一張單，標題下那一行寫當天的日期與計畫依據，印出當天最後的單：1 號車 06:00、2 號車 06:30 先發" do
      start_day.then { before_print }
      line = "#{RoutePage::Format.day_label(Time.zone.today)}當天調度的單・依 2026-10-19（一） 平日 的實測鋪排・p85・停車端休息 15 分"
      expect(under_print_styles(sheet_heads)).to eq([ [ line, "06:00" ], [ line, "06:30" ] ])
    end
  end

  # Each printed sheet's notes, by its vehicle.
  def printed_notes = page.evaluate_script(<<~JS)
    Object.fromEntries([...document.querySelectorAll("[data-record-sheets] [data-vehicle]")]
      .map((sheet) => [sheet.dataset.vehicle, [...sheet.querySelectorAll("[data-sheet-notes] li")].map((note) => note.textContent)]))
  JS

  # A script giving each printed sheet's first row, by its vehicle, as its
  # departure, arrival, return departure and return arrival as printed.
  def first_rows = <<~JS
    Object.fromEntries([...document.querySelectorAll("[data-record-sheets] [data-vehicle]")]
      .map((sheet) => [sheet.dataset.vehicle, [...sheet.querySelectorAll("tbody tr[data-row]:first-child :is(td[data-departure], td[data-arrival])")].map((cell) => cell.innerText)]))
  JS

  # Vehicle 1 recorded back at 乙站 at 07:00, planned at 06:50, and its 08:00
  # from 乙站 given to vehicle 2, which gives vehicle 1 its 08:30.
  def swap_after_late_return = show_end("乙站", "返程").then { record_back(1, "0700") }.then { give("08:00", 2) }

  describe "單子上的記號與註記" do
    it "規格的單子下面的註記：2 號車開 1 號車的 08:00，那一格印＊、註記原排 1 號車；1 號車 07:00 回到印†、註記原定 06:50" do
      start_day.then { swap_after_late_return }.then { before_print }
      expect([ under_print_styles(first_rows), printed_notes ]).to eq([ { "1" => %w[06:00 07:00† 08:30＊ 09:15], "2" => %w[06:30 07:20 08:00＊ 08:45] },
                                                                          { "1" => [ "＊ 08:30 原排 2 號車", "† 07:00 是記下的回到時刻，原定 06:50" ], "2" => [ "＊ 08:00 原排 1 號車" ] } ])
    end

    it "帶＊、†、‡ 三行註記的單照樣一車一頁：1 號車的 08:30 改成 08:35，印出來一共四頁" do
      start_day.then { swap_after_late_return }.then { retype("08:30", "0835") }.then { before_print }
      expect([ printed_notes["1"], (1..5).map { printed_page?(it) } ])
        .to eq([ [ "＊ 08:35 原排 2 號車", "† 07:00 是記下的回到時刻，原定 06:50", "‡ 08:35 改過，原本 08:30" ], [ true, true, true, true, false ] ])
    end

    it "沒有記號的單不印註記" do
      start_day.then { before_print }
      expect(all("[data-record-sheets] [data-sheet-notes]", visible: :all).size).to eq(0)
    end
  end
end
