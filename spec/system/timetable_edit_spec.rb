require "rails_helper"

# The timetable in the browser: the sheets are laid out from the embedded
# data once the script runs, the controls lay them out again without a
# request, the rest and the percentile follow into the address, and the
# dispatcher's edits are recomputed in the page.
RSpec.describe "班表在瀏覽器裡鋪排與微調", :js, type: :system do
  # A complete trip of the day starting at `start` that runs for `minutes`.
  def add_trip(route_day, start, minutes, go_back)
    start_time = Time.zone.parse("2026-10-19 #{start}")
    route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back:, band: "other", start_time:, end_time: start_time + minutes.minutes,
                            first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                            start_from_arrival: false, end_from_departure: false)
  end

  # The spec's four-departure day: direction 0 from 甲站 at 06:00 and 06:30
  # running 50 minutes, direction 1 from 乙站 at 07:00 and 07:30 running 45.
  # Laid out with 15 rest minutes they take three vehicles.
  before do
    route_day = create(:route_day, day: Date.new(2026, 10, 19))
    route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 5, stop_name: "乙站" } ])
    [ [ "06:00", 50, 0 ], [ "06:30", 50, 0 ], [ "07:00", 45, 1 ], [ "07:30", 45, 1 ] ].each { |start, minutes, go_back| add_trip(route_day, start, minutes, go_back) }
  end

  def open_timetable(**params)
    visit route_timetable_path(9001, **params)
    find("[data-sheets] [data-vehicle]", match: :first)
  end

  # The seven time and stop cells of a row as the browser shows them, in the
  # paper's order: departure, first stop, arrival, stop, return departure,
  # return arrival, stop after. A departure cell is its input's value, since
  # the printed text is hidden on screen.
  def row_cells(vehicle, row)
    all("[data-sheets] [data-vehicle='#{vehicle}'] tr[data-row='#{row}'] :is([data-departure], [data-slot=origin], [data-arrival], [data-stop])")
      .map { |cell| cell.has_css?("input", wait: 0) ? cell.find("input").value : cell.text }
  end

  def figures(*names) = names.map { find("[data-timetable-header] [data-value='#{it}']").text }

  def sheet_numbers = all("[data-sheets] [data-vehicle]").map { it["data-vehicle"] }

  def rendered_mark = find("main[data-timetable]")["data-rendered"]

  def address = Rack::Utils.parse_query(URI(page.current_url).query)

  # Whether the element with the keyboard focus matches the selector.
  def focused?(selector) = page.evaluate_script("document.activeElement.matches(#{selector.to_json})")

  # Leaves for the home page through the site bar and comes back with the
  # browser's back button, which Turbo answers with the page from its cache.
  def leave_and_come_back
    find("[data-site-bar] a[href='/']").click
    assert_no_selector("main[data-timetable]")
    page.go_back
    find("main[data-timetable] [data-sheets] [data-vehicle]", match: :first)
  end

  # The sheet component's wording for a key, with the values filled in.
  def sheet_text(key, **values) = format(YAML.load_file(Rails.root.join("app/components/timetable_sheet_component.yml"), aliases: true).dig("tw", key), **values)

  # Types into a number control and leaves it, which is when the page acts.
  def set_control(name, value) = find("[data-timetable-controls] input[name='#{name}']").set(value).send_keys(:tab)

  # Picks p50 and 10 rest minutes, and waits for the header to show the rest.
  def switch_to_p50_rest_10
    select "p50", from: "p"
    set_control("buffer", "10")
    find("[data-timetable-header] [data-value='buffer']", text: "10")
  end

  # Every hour of this day has two trips, so every planned run time falls back
  # to the whole day and every arrival carries the mark.
  it "載入後三張單：車次 1 一列 06:00、甲站、06:50＊、40、07:30、08:15＊；頁首 3 台車、去返各 2 班、改過 0 處、跟著往後推 0 處" do
    open_timetable
    expect([ sheet_numbers, find("[data-vehicle='1'] [data-slot=title]").text, row_cells(1, 1), figures("vehicles", "departures-0", "departures-1", "edited", "pushed") ])
      .to eq([ %w[1 2 3], "車次 1", [ "06:00", "甲站", "06:50＊", "40", "07:30", "08:15＊", "" ], %w[3 2 2 0 0] ])
  end

  it "加一列的說明寫著那張單第一趟的方向：1 號車是去程，3 號車是返程" do
    open_timetable
    add_label = YAML.load_file(Rails.root.join("app/components/timetable_sheet_component.yml"), aliases: true).dig("tw", "add_label")
    expect([ 1, 3 ].map { find("[data-vehicle='#{it}'] [data-slot=add-label]").text }).to eq([ format(add_label, direction: "去程"), format(add_label, direction: "返程") ])
  end

  it "腳本跑過後：需要 JavaScript 那一句藏起來，列印鈕出現；車次 3 只有一趟，第二趟的格子空白、這張單不到 4 小時" do
    open_timetable
    expect([ page.has_no_css?("[data-needs-script]", visible: :visible), page.has_css?("button[data-print]"), row_cells(3, 1), find("[data-vehicle='3'] [data-rest-credit]")["data-rest-credit"] ])
      .to eq([ true, true, [ "07:00", "乙站", "07:45＊", "", "", "", "" ], "" ])
  end

  it "螢幕上只看得到有趟次的列：車次 1 一列，印刷用的 13 列空白列藏著" do
    open_timetable
    expect([ all("[data-vehicle='1'] tbody tr", visible: :visible).size, all("[data-vehicle='1'] tr[data-filler]", visible: :all).size ]).to eq([ 1, 13 ])
  end

  it "改控制項不送請求：去程 06 時改成 1 班，兩台車、去程 1 班返程 2 班，頁面沒有重新載入" do
    open_timetable
    mark = rendered_mark
    set_control("departures[0][6]", "1")
    find("[data-timetable-header] [data-value='vehicles']", text: "2")
    expect([ sheet_numbers, figures("departures-0", "departures-1"), rendered_mark ]).to eq([ %w[1 2], %w[1 2], mark ])
  end

  it "23 時加三班去程：23:40 那一趟的到達印成隔日 00:30，那一趟退回全天有標記與說明" do
    open_timetable
    set_control("departures[0][23]", "3")
    cell = find("[data-arrival='1470']")
    expect([ cell.text, cell[:"data-fallback"].nil?, cell.ancestor("[data-vehicle]").find("[data-fallback-legend]", visible: :all).visible? ]).to eq([ "隔日 00:30＊", false, true ])
  end

  it "換 p 成 50 與休息成 10：超時表只有 p50 那一列選著，網址帶 p=50 與 buffer=10，瀏覽紀錄沒有多一筆" do
    open_timetable(day: "2026-10-19", range: "7d")
    length = page.evaluate_script("history.length")
    switch_to_p50_rest_10
    expect([ all("[data-section=overruns] tr[data-selected]").map { it["data-percentile"] }, address, page.evaluate_script("history.length") ])
      .to eq([ [ "50" ], { "day" => "2026-10-19", "range" => "7d", "buffer" => "10", "p" => "50" }, length ])
  end

  it "重新載入保得住：換成 p50 與休息 10 之後重新載入，控制項與頁首都是 50 與 10" do
    open_timetable
    switch_to_p50_rest_10
    visit page.current_url
    expect([ find("[data-timetable-controls] select[name=p]").value, find("[data-timetable-controls] input[name=buffer]").value, figures("percentile", "buffer") ]).to eq([ "50", "10", %w[50 10] ])
  end

  it "再加一台車：選返程、打 15:00，多一張 4 號車，一列 15:00、乙站、15:45＊、15、16:00、16:50＊，兩格改過，頁首 4 台車、2 處" do
    open_timetable
    within("[data-add-vehicle]") { find("select").select("返程").then { find("input").set("15:00") }.then { click_button "加一台車" } }
    find("[data-sheets] [data-vehicle='4']")
    expect([ row_cells(4, 1), all("[data-vehicle='4'] [data-departure][data-edited]").size, figures("vehicles", "edited") ])
      .to eq([ [ "15:00", "乙站", "15:45＊", "15", "16:00", "16:50＊", "" ], 2, %w[4 2] ])
  end

  it "加一台車打 1500（不打冒號）：多一張 4 號車，跟打 15:00 一樣" do
    open_timetable
    within("[data-add-vehicle]") { find("select").select("返程").then { find("input").set("1500") }.then { click_button "加一台車" } }
    find("[data-sheets] [data-vehicle='4']")
    expect([ sheet_numbers, row_cells(4, 1) ]).to eq([ %w[1 2 3 4], [ "15:00", "乙站", "15:45＊", "15", "16:00", "16:50＊", "" ] ])
  end

  it "加一台車打 1500 按加一台車：焦點回到加一台車的輸入框，輸入框是空的" do
    open_timetable
    within("[data-add-vehicle]") { find("input").set("1500").then { click_button "加一台車" } }
    find("[data-sheets] [data-vehicle='4']")
    expect([ focused?("[data-add-vehicle-input]"), find("[data-add-vehicle-input]").value ]).to eq([ true, "" ])
  end

  it "加一台車打 25:70：那一塊出現說明，引用 25:70、寫出時刻可以怎麼打，輸入框標成錯誤並指到它" do
    open_timetable
    within("[data-add-vehicle]") { find("input").set("25:70").then { click_button "加一台車" } }
    message = find("[data-add-vehicle] [data-add-vehicle-rejection]")
    input = find("[data-add-vehicle-input]")
    expect([ input[:"aria-invalid"], input[:"aria-describedby"] == message[:id], message.text ]).to eq([ "true", true, I18n.t("times.rejected_typed", typed: "25:70", writings: I18n.t("times.accepted_writings")) ])
  end

  it "加一台車打 25:70 被退回後改打 1500 再加：說明不見，沒有標成錯誤或無效的地方，多一張 4 號車" do
    open_timetable
    within("[data-add-vehicle]") { find("input").set("25:70").then { click_button "加一台車" }.then { find("input").set("1500") }.then { click_button "加一台車" } }
    find("[data-sheets] [data-vehicle='4']")
    expect([ page.has_no_css?("[data-add-vehicle-rejection]", visible: :visible), page.has_no_css?("[aria-invalid], [data-invalid]", visible: :all), sheet_numbers ]).to eq([ true, true, %w[1 2 3 4] ])
  end

  it "加一台車打 25:70 被退回後刪掉 1 號車的列：加一台車的說明不見，沒有標成錯誤或無效的地方" do
    open_timetable
    within("[data-add-vehicle]") { find("input").set("25:70").then { click_button "加一台車" } }
    within("[data-vehicle='1'] tr[data-row='1']") { click_button "刪這一列" }
    expect([ page.has_no_css?("[data-add-vehicle-rejection]", visible: :visible), page.has_no_css?("[aria-invalid], [data-invalid]", visible: :all) ]).to eq([ true, true ])
  end

  it "加一台車打 25:70 被退回後到首頁再按上一頁：帶回來的班表頁沒有加一台車的說明，也沒有標成錯誤或無效的地方" do
    open_timetable
    within("[data-add-vehicle]") { find("input").set("25:70").then { click_button "加一台車" } }
    leave_and_come_back
    expect([ page.has_no_css?("[data-add-vehicle-rejection]", visible: :visible), page.has_no_css?("[aria-invalid], [data-invalid]", visible: :all) ]).to eq([ true, true ])
  end

  it "加車的時刻不合格式：控制項標無效、車數不變" do
    open_timetable
    within("[data-add-vehicle]") { find("input").set("25:70").then { click_button "加一台車" } }
    expect([ find("[data-add-vehicle]")[:"data-invalid"].nil?, figures("vehicles") ]).to eq([ false, [ "3" ] ])
  end

  describe "手動微調" do
    # Five more trips in each hour the scenarios touch, so no hour falls back:
    # direction 0 runs 50 minutes in the 06 hour and 48 in the 11 hour,
    # direction 1 runs 45 in the 07 hour and 46 in the 12 hour.
    before do
      route_day = RouteDay.sole
      [ [ 6, 50, 0 ], [ 7, 45, 1 ], [ 11, 48, 0 ], [ 12, 46, 1 ] ].each { |hour, minutes, go_back| 5.times { add_trip(route_day, format("%02d:%02d", hour, 5 + (it * 10)), minutes, go_back) } }
    end

    # The timetable with one outbound departure in the 06 hour and two inbound
    # in the 07 hour and nothing else: vehicle 1 runs 06:00 to 06:50 and 07:30
    # to 08:15, vehicle 2 runs 07:00 to 07:45.
    def open_for_edits
      open_timetable
      { "departures[0][6]" => 1, "departures[1][7]" => 2, "departures[0][11]" => 0, "departures[1][12]" => 0 }.each { |name, value| set_control(name, value) }
      find("[data-timetable-header] [data-value='vehicles']", text: "2")
    end

    # The first (0) or second (1) departure field of a row.
    def departure_cell(vehicle, row, which) = all("[data-vehicle='#{vehicle}'] tr[data-row='#{row}'] [data-departure]")[which]

    def retype(vehicle, row, which, value) = departure_cell(vehicle, row, which).find("input").set(value).send_keys(:tab)

    # The departure field that has the keyboard focus, as its cell's sheet and
    # trip index; nil when the focus is anywhere else.
    def focused_departure
      page.evaluate_script('(() => { const cell = document.activeElement?.closest("[data-departure]"); return cell ? [cell.dataset.sheet, cell.dataset.index] : null })()')
    end

    it "改返回那趟成 07:20：那一列 06:00、甲站、06:50、30、07:20、08:05，只有那一格標改過，頁首 1 處" do
      open_for_edits
      retype(1, 1, 1, "07:20")
      find("[data-vehicle='1'] tr[data-row='1'] td[data-stop]", text: "30")
      expect([ row_cells(1, 1), (0..1).map { departure_cell(1, 1, it)[:"data-edited"].nil? }, figures("edited") ])
        .to eq([ [ "06:00", "甲站", "06:50", "30", "07:20", "08:05", "" ], [ true, false ], [ "1" ] ])
    end

    it "打 0720（不打冒號）：格子顯示 07:20，那一列 06:00、甲站、06:50、30、07:20、08:05，頁首 1 處" do
      open_for_edits
      retype(1, 1, 1, "0720")
      find("[data-vehicle='1'] tr[data-row='1'] td[data-stop]", text: "30")
      expect([ row_cells(1, 1), figures("edited") ]).to eq([ [ "06:00", "甲站", "06:50", "30", "07:20", "08:05", "" ], [ "1" ] ])
    end

    it "原本 07:30 打 0730：格子換成 07:30 的寫法，沒有標改過，頁首 0 處" do
      open_for_edits
      retype(1, 1, 1, "0730")
      cell = departure_cell(1, 1, 1)
      expect([ cell.find("input").value, cell[:"data-edited"].nil?, figures("edited") ]).to eq([ "07:30", true, [ "0" ] ])
    end

    it "返回發車格打 0720 按 Enter：格子 07:20、停留 30，焦點還在那一格" do
      open_for_edits
      departure_cell(1, 1, 1).find("input").set("0720").send_keys(:enter)
      expect([ departure_cell(1, 1, 1).find("input").value, row_cells(1, 1)[3], focused_departure ]).to eq([ "07:20", "30", %w[1 1] ])
    end

    it "發車格打 0605 按 Tab：格子 06:05，焦點在同一列的返回發車格" do
      open_for_edits
      retype(1, 1, 0, "0605")
      expect([ departure_cell(1, 1, 0).find("input").value, focused_departure ]).to eq([ "06:05", %w[1 1] ])
    end

    it "返回發車格打 0720 後直接點同一列的發車格：焦點在被點的那一格，返回那趟是 07:20" do
      open_for_edits
      departure_cell(1, 1, 1).find("input").set("0720").then { departure_cell(1, 1, 0).find("input").click }
      expect([ focused_departure, departure_cell(1, 1, 1).find("input").value ]).to eq([ %w[1 0], "07:20" ])
    end

    it "改成 06:45 接不上：停留印 −5" do
      open_for_edits
      retype(1, 1, 1, "06:45")
      find("[data-vehicle='1'] tr[data-row='1'] td[data-stop]", text: "−5")
      expect(row_cells(1, 1)[3]).to eq("−5")
    end

    it "1 號車去程打 06:45：那一列 06:45、甲站、07:35、15、07:50、08:35，07:50 標跟著往後推、說明寫 20 分與原本 07:30，頁首改過 1、推 1，2 號車不動" do
      open_for_edits
      retype(1, 1, 0, "0645").then { find("[data-vehicle='1'] tr[data-row='1'] [data-departure][data-pushed]") }
      pushed = departure_cell(1, 1, 1)
      expect([ row_cells(1, 1), pushed.find("input")[:title], figures("edited", "pushed"), row_cells(2, 1)[0..2] ])
        .to eq([ [ "06:45", "甲站", "07:35", "15", "07:50", "08:35", "" ], sheet_text("pushed", minutes: 20, time: "07:30"), %w[1 1], [ "07:00", "乙站", "07:45" ] ])
    end

    it "去程打 06:45 再打回 06:00：返程回到 07:30，那一列 06:00、甲站、06:50、40、07:30、08:15，沒有標跟著往後推的格子，頁首推 0" do
      open_for_edits
      retype(1, 1, 0, "0645").then { find("[data-vehicle='1'] [data-departure][data-pushed]") }
      retype(1, 1, 0, "0600").then { find("[data-vehicle='1'] tr[data-row='1'] td[data-stop]", text: "40") }
      expect([ row_cells(1, 1), all("[data-sheets] [data-departure][data-pushed]").size, figures("edited", "pushed") ])
        .to eq([ [ "06:00", "甲站", "06:50", "40", "07:30", "08:15", "" ], 0, %w[1 0] ])
    end

    it "被推過的 07:50 照原樣打 0750：仍標跟著往後推、沒有標改過，頁首改過 1、推 1" do
      open_for_edits
      retype(1, 1, 0, "0645").then { find("[data-vehicle='1'] [data-departure][data-pushed]") }
      retype(1, 1, 1, "0750")
      cell = departure_cell(1, 1, 1)
      expect([ cell.find("input").value, cell[:"data-pushed"].nil?, cell[:"data-edited"].nil?, figures("edited", "pushed") ]).to eq([ "07:50", false, true, %w[1 1] ])
    end

    it "在 1 號車加一列 11:00，再把那一列的去程改成 11:30：那一列 11:30、甲站、12:18、15、12:33、13:19，12:33 同時標改過與跟著往後推" do
      open_for_edits
      within("[data-vehicle='1']") { find("[data-add-input]").set("11:00").then { click_button "加一列" } }
      retype(1, 2, 0, "1130").then { find("[data-vehicle='1'] tr[data-row='2'] [data-departure][data-pushed][data-edited]") }
      expect([ row_cells(1, 2), departure_cell(1, 2, 1).find("input")[:title], figures("edited", "pushed") ])
        .to eq([ [ "11:30", "甲站", "12:18", "15", "12:33", "13:19", "" ], [ sheet_text("edited"), sheet_text("pushed", minutes: 30, time: "12:03") ].join(sheet_text("title_separator")), %w[2 1] ])
    end

    it "刪第一列：08 時兩班去程讓 1 號車多一列 08:30，刪第一列後只剩列號 1、08:30 發" do
      open_for_edits
      set_control("departures[0][8]", 2).then { find("[data-vehicle='1'] tr[data-row='2']") }
      within("[data-vehicle='1'] tr[data-row='1']") { click_button "刪這一列" }
      find("[data-vehicle='1'] tr[data-row='1'] [data-departure='510']")
      expect(all("[data-vehicle='1'] tr[data-row]").map { |row| [ row["data-row"], row.find("[data-departure] input").value ] }).to eq([ [ "1", "08:30" ] ])
    end

    it "在 1 號車加一列 11:00：多一列 11:00、甲站、11:48、15、12:03、12:49，兩個發車格都改過，頁首 2 處" do
      open_for_edits
      within("[data-vehicle='1']") { find("[data-add-input]").set("11:00").then { click_button "加一列" } }
      find("[data-vehicle='1'] tr[data-row='2']")
      expect([ row_cells(1, 2), all("[data-vehicle='1'] tr[data-row='2'] [data-departure][data-edited]").size, figures("edited") ])
        .to eq([ [ "11:00", "甲站", "11:48", "15", "12:03", "12:49", "" ], 2, [ "2" ] ])
    end

    it "1 號車的加一列打 1100 按 Enter：多一列 11:00，焦點在 1 號車的加一列，輸入框是空的" do
      open_for_edits
      within("[data-vehicle='1']") { find("[data-add-input]").set("1100").send_keys(:enter) }
      find("[data-vehicle='1'] tr[data-row='2']")
      expect([ row_cells(1, 2)[0], focused?("[data-vehicle='1'] [data-add-input]"), find("[data-vehicle='1'] [data-add-input]").value ]).to eq([ "11:00", true, "" ])
    end

    it "打 25:70：那一格標無效、值回到 07:30、頁首改過仍是 0，那張單的說明引用 25:70" do
      open_for_edits
      retype(1, 1, 1, "25:70")
      cell = departure_cell(1, 1, 1)
      expect([ cell[:"data-invalid"].nil?, cell.find("input").value, figures("edited"), find("[data-vehicle='1'] [data-rejection]").text.include?("25:70") ]).to eq([ false, "07:30", [ "0" ], true ])
    end

    it "打 23:70：格子回到 07:30，輸入框標成錯誤並指到 1 號車的說明，說明引用 23:70、寫出時刻可以怎麼打" do
      open_for_edits
      input = retype(1, 1, 1, "23:70")
      message = find("[data-vehicle='1'] [data-rejection]")
      expect([ input.value, input[:"aria-invalid"], input[:"aria-describedby"] == message[:id], message.text ])
        .to eq([ "07:30", "true", true, I18n.t("times.rejected_typed", typed: "23:70", writings: I18n.t("times.accepted_writings")) ])
    end

    it "23:70 被退回後，同一列的發車格打 0605：頁面上沒有標成錯誤或無效的格子，說明不見" do
      open_for_edits
      retype(1, 1, 1, "23:70").then { retype(1, 1, 0, "0605") }
      expect([ page.has_no_css?("[aria-invalid], [data-invalid]", visible: :all), page.has_no_css?("[data-rejection]", visible: :visible) ]).to eq([ true, true ])
    end

    it "23:70 被退回後，同一格打 0730（原本的時刻）：頁面上沒有標成錯誤或無效的格子，說明不見" do
      open_for_edits
      retype(1, 1, 1, "23:70").then { retype(1, 1, 1, "0730") }
      expect([ page.has_no_css?("[aria-invalid], [data-invalid]", visible: :all), page.has_no_css?("[data-rejection]", visible: :visible) ]).to eq([ true, true ])
    end

    # Chrome fires no change for the same text typed again.
    it "23:70 被退回後，同一格照原樣打 07:30 按 Tab：頁面上沒有標成錯誤或無效的格子，說明不見" do
      open_for_edits
      retype(1, 1, 1, "23:70").then { retype(1, 1, 1, "07:30") }
      expect([ page.has_no_css?("[aria-invalid], [data-invalid]", visible: :all), page.has_no_css?("[data-rejection]", visible: :visible) ]).to eq([ true, true ])
    end

    it "23:70 被退回後，同一格照原樣打 07:30 按 Enter：頁面上沒有標成錯誤或無效的格子，說明不見" do
      open_for_edits
      departure_cell(1, 1, 1).find("input").set("23:70").send_keys(:enter).set("07:30").send_keys(:enter)
      expect([ page.has_no_css?("[aria-invalid], [data-invalid]", visible: :all), page.has_no_css?("[data-rejection]", visible: :visible) ]).to eq([ true, true ])
    end

    it "1 號車打 23:70 被退回後，2 號車打 25:70：只剩 2 號車那一格標成錯誤，1 號車的說明不見" do
      open_for_edits
      retype(1, 1, 1, "23:70").then { retype(2, 1, 0, "25:70") }
      expect([ all("[aria-invalid]").map { it.ancestor("[data-vehicle]")["data-vehicle"] }, page.has_no_css?("[data-vehicle='1'] [data-rejection]", visible: :visible) ]).to eq([ [ "2" ], true ])
    end

    it "加一列什麼都沒打就按加一列：加一列的輸入框標成錯誤，1 號車的說明只寫時刻可以怎麼打" do
      open_for_edits
      within("[data-vehicle='1']") { click_button "加一列" }
      expect([ find("[data-vehicle='1'] [data-add-input]")[:"aria-invalid"], find("[data-vehicle='1'] [data-rejection]").text ]).to eq([ "true", I18n.t("times.accepted_writings") ])
    end

    # Chrome fires change on leaving a field whose text differs from when it
    # was first typed into, even after the page wrote the field back itself.
    it "返回發車格打 0720 按 Enter，再打 23:70 按 Enter 被退回，按 Tab 離開：那一格仍標成錯誤，說明還在" do
      open_for_edits
      departure_cell(1, 1, 1).find("input").set("0720").send_keys(:enter).set("23:70").send_keys(:enter, :tab)
      expect([ departure_cell(1, 1, 1).find("input")[:"aria-invalid"], find("[data-vehicle='1'] [data-rejection]").text.include?("23:70") ]).to eq([ "true", true ])
    end

    it "1 號車打 23:70 被退回後，在 2 號車的第一個發車格沒打字就按 Enter：1 號車那一格仍標成錯誤，說明還在" do
      open_for_edits
      retype(1, 1, 1, "23:70").then { departure_cell(2, 1, 0).find("input").send_keys(:enter) }
      expect([ departure_cell(1, 1, 1).find("input")[:"aria-invalid"], find("[data-vehicle='1'] [data-rejection]").text.include?("23:70") ]).to eq([ "true", true ])
    end

    it "改過之後換 p：重新鋪排，手動改過的歸 0" do
      open_for_edits
      retype(1, 1, 1, "07:20").then { find("[data-timetable-header] [data-value='edited']", text: "1") }
      select "p50", from: "p"
      find("[data-timetable-header] [data-value='edited']", text: "0")
      expect(figures("edited", "percentile")).to eq(%w[0 50])
    end
  end
end
