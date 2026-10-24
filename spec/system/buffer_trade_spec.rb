require "rails_helper"

# The buffer estimate in the browser: moving the rest or the lateness slider
# replaces the figures with those of a point of the curve data in the
# response, without a request; changing the hours reloads only the block.
RSpec.describe "換休息試算的拉桿", :js, type: :system do
  # One stored day of route 9001, whose both ends stop, with layovers ending in
  # direction 1 at 08:00 (5 minutes), 08:20 (20), 09:10 (2) and 10:30 (30).
  before do
    route_day = create(:route_day, day: Date.new(2026, 10, 19))
    [ [ "08:00", 5 ], [ "08:20", 20 ], [ "09:10", 2 ], [ "10:30", 30 ] ].each do |time, minutes|
      end_time = Time.zone.parse("2026-10-19 #{time}")
      route_day.layovers.create!(bus_id: "TEST-0001", go_back: 1, end_time:, next_start_time: end_time + minutes.minutes)
    end
  end

  def figure_names = %w[vehicle-hours-lower vehicle-hours-upper next-minute-lower next-minute-upper achieved-late]

  def open_estimate = visit(route_path(9001, day: "2026-10-19", range: "7d"))

  def rendered_mark = find("section[data-section=buffer-trade]")["data-rendered"]

  def address = Rack::Utils.parse_query(URI(page.current_url).query)

  def slide(name, value) = find("input[type=range][name=#{name}]").set(value)

  # The figures the block shows now.
  def figures = page.evaluate_script("#{figure_names.to_json}.map((name) => document.querySelector(`[data-value=\"${name}\"]`).textContent.trim())")

  # The same figures as the curve data's point at the given minutes to hold.
  def point_figures(hold)
    point = JSON.parse(page.evaluate_script("document.querySelector('script[data-buffer-trade-curve]').textContent"))["points"][hold]
    [ *point["vehicle_hours"], *point["next_minute"], point["achieved"] ]
  end

  def leave_and_come_back
    find("[data-site-bar] a[href='/']").click
    find("[data-section=hero]")
    page.go_back
  end

  it "休息拉桿移到 10：數字換成曲線資料第 10 點的，這一塊沒有重新載入" do
    open_estimate
    mark = rendered_mark
    slide("buffer", 10)
    expect([ figures, rendered_mark ]).to eq([ point_figures(10), mark ])
  end

  it "休息拉桿移到 10：網址換成 buffer=10，day 與 range 照留，瀏覽紀錄沒有多一筆" do
    open_estimate
    length = page.evaluate_script("history.length")
    slide("buffer", 10)
    expect([ address.slice("buffer", "day", "range"), page.evaluate_script("history.length") ]).to eq([ { "buffer" => "10", "day" => "2026-10-19", "range" => "7d" }, length ])
  end

  it "開始小時改成 9：這一塊重新載入，網址帶 from=9、to=24 與目前的 buffer、late、day、range" do
    open_estimate
    mark = rendered_mark
    find("select[name=from]").select("9")
    find("section[data-section=buffer-trade]:not([data-rendered='#{mark}'])")
    expect(address.slice("from", "to", "buffer", "late", "day", "range")).to eq("from" => "9", "to" => "24", "buffer" => "15", "late" => "0", "day" => "2026-10-19", "range" => "7d")
  end

  it "晚到移到 6、點到首頁再按上一頁：晚到拉桿是 6，數字是要留 21 分鐘那一點的" do
    open_estimate
    slide("late", 6)
    leave_and_come_back
    expect([ find_field("late", with: "6").value, figures ]).to eq([ "6", point_figures(21) ])
  end
end
