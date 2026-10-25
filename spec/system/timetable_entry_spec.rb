require "rails_helper"

# The way from the route page to the timetable in the browser: the link on the
# buffer estimate card sits inside that card's turbo-frame, so it has to leave
# the frame and load the whole timetable page.
RSpec.describe "從路線頁到班表", :js, type: :system do
  before do
    route_day = create(:route_day, day: Date.new(2026, 10, 19))
    end_time = Time.zone.parse("2026-10-19 08:00")
    route_day.layovers.create!(bus_id: "TEST-0001", go_back: 1, end_time:, next_start_time: end_time + 20.minutes)
  end

  def address = URI(page.current_url).then { [ it.path, Rack::Utils.parse_query(it.query) ] }

  it "點換休息試算卡上的連結：整頁換成班表頁，帶著當時的 day、range 與 buffer" do
    visit route_path(9001, day: "2026-10-19", range: "7d", buffer: "10")
    find("[data-section=buffer-trade] a[data-timetable-link]").click
    find("main[data-timetable]")
    expect(address).to eq([ "/routes/9001/timetable", { "day" => "2026-10-19", "range" => "7d", "buffer" => "10" } ])
  end
end
