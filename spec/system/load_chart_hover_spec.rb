require "rails_helper"

# Pointing at an overlap stretch on the load chart, or at its entry in the
# list below, highlights both. Alpine does the highlighting, which component
# specs do not run, so it is checked in the browser.
RSpec.describe "沿線人數圖的重疊路段連動", :js, type: :system do
  # Outbound stops 0 to 4 make two stretches (0–1 and 3–4); inbound stops 5
  # to 9 make one (5–6).
  def store_day
    route_day = create(:route_day, mrt_exits_day: Date.new(2026, 10, 19))
    [ [ 0, %w[甲站 乙站 丙站 丁站 戊站], [ 400, 450, 900, 250, 300 ] ], [ 1, %w[戊站 丁站 丙站 乙站 甲站], [ 300, 350, 900, 900, 900 ] ] ].each do |go_back, names, meters|
      names.each_with_index do |name, index|
        route_day.stops.create!(go_back:, seq: (go_back * 5) + index, stop_name: name, nearest_exit_name: "出口", nearest_exit_meters: meters[index])
      end
    end
  end

  # Alpine has started once the time band picker, cloaked until then, shows.
  def visit_day
    visit route_path(9001, day: "2026-10-19")
    find("[data-section=load-chart] [data-band-switch]")
  end

  # The spans and list entries highlighted after pointing at `selector`:
  # direction, element and number.
  def highlighted_after_pointing_at(selector)
    find(selector).hover
    page.has_css?("[data-span-number][data-active]", wait: 2)
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[data-span-number][data-active]")]
        .map((node) => [node.closest("[data-direction]").dataset.direction, node.tagName.toLowerCase(), node.dataset.spanNumber])
    JS
  end

  before do
    store_day
    visit_day
  end

  it "指到去程清單第 2 列，只有去程第 2 段與清單第 2 列變深" do
    expect(highlighted_after_pointing_at("[data-direction='0'] li[data-span-number='2']")).to eq([ %w[0 g 2], %w[0 li 2] ])
  end

  it "指到去程第 1 段的編號圓，只有去程第 1 段與清單第 1 列變深，返程第 1 段不變" do
    expect(highlighted_after_pointing_at("[data-direction='0'] g[data-span-number='1'] circle[data-span-marker]")).to eq([ %w[0 g 1], %w[0 li 1] ])
  end

  it "指到之後移到這一區的標題上，沒有任何一段變深" do
    highlighted_after_pointing_at("[data-direction='0'] li[data-span-number='2']")
    find("[data-section=load-chart] h2").hover
    expect(page).to have_no_css("[data-span-number][data-active]")
  end
end
