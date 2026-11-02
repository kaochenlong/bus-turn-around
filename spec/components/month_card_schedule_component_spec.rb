# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardScheduleComponent, type: :component do
  let(:route_card) { create(:route_card) }
  let(:month_card) { RoutePage::MonthCard.new(route_card) }

  def store(day, **attributes)
    create(:route_day, day: Date.iso8601(day), published_schedule_day: Date.iso8601(day), member_names: { "9050" => "測試幹線經己站" }, **attributes)
  end

  def date_value(route_day) = RoutePage::ScheduleComparison.date_value(route_day.day, route_day.day_type)

  def add_period(route_day, from, to, low, high, route_id: 9001)
    create(:route_day_published_headway, route_day:, route_id:, date_value: date_value(route_day), start_minute: from, end_minute: to, low_minutes: low, high_minutes: high)
  end

  def add_departures(route_day, *minutes, route_id: 9001)
    minutes.each { create(:route_day_published_departure, route_day:, route_id:, date_value: date_value(route_day), minute: it) }
  end

  def add_trip(route_day, clock, minutes: 30, go_back: 0, bus_id: "TEST-#{clock}", route_id: 9001)
    start_time = Time.zone.parse("#{route_day.day} #{clock}")
    create(:trip, route_day:, route_id:, go_back:, bus_id:, start_time:, end_time: start_time + minutes.minutes)
  end

  # A cycle p50 for the given route days, standing in for RoutePage::Cycles.
  def stub_cycle(p50)
    row = RoutePage::Cycles::Row.new(hour: nil, n_round_trips: 0, round_trip_percentiles: [ nil, nil ], n_cycles: 1, cycle_percentiles: [ nil, p50 ])
    allow(month_card).to receive(:cycles).and_return(instance_double(RoutePage::Cycles, total: row, rows: []))
  end

  def render_block = render_inline(described_class.new(month_card:))

  def table_rows = page.all("[data-schedule-table] tbody tr")

  def row_texts(row) = row.all("td").map(&:text)

  def chart_points(chart, series)
    page.all("[data-schedule-chart='#{chart}'] [data-series='#{series}'] circle", visible: :all).map { [ it["data-hour"].to_f, it["data-value"].to_f ] }
  end

  describe "時段列" do
    it "時段、班距與換算每小時班數：06:30 到 08:00、4 到 6 分是 10–15" do
      store("2026-10-19").tap { add_period(it, 390, 480, 4, 6) }
      render_block
      expect(row_texts(table_rows.first).first(3)).to eq([ "06:30–08:00", "4–6 分", "10–15" ])
    end

    it "量到的發車取一位小數，路上的車取整數，要幾台是範圍" do
      route_day = store("2026-10-19").tap { add_period(it, 360, 420, 4, 6) }
      stub_cycle(182.2)
      { "06:00" => 0, "06:10" => 1, "06:20" => 1 }.each { |clock, go_back| add_trip(route_day, clock, minutes: 60, go_back:) }
      render_block
      expect(row_texts(table_rows.first).drop(3)).to eq([ "1.0", "2.0", "3", "30–46" ])
    end

    it "沒有週期：要幾台是 —" do
      store("2026-10-19").tap { add_period(it, 360, 420, 4, 6) }
      render_block
      expect(row_texts(table_rows.first).last).to eq("—")
    end

    it "上下界相同：只寫一個數" do
      store("2026-10-19").tap { add_period(it, 360, 420, 30, 30) }
      render_block
      expect(row_texts(table_rows.first).values_at(1, 2)).to eq([ "30 分", "2" ])
    end

    it "到午夜的時段寫 24:00" do
      store("2026-10-19").tap { add_period(it, 1020, 1440, 30, 30) }
      render_block
      expect(row_texts(table_rows.first).first).to eq("17:00–24:00")
    end

    it "下界最小的時段標出來" do
      store("2026-10-19").tap { |day| [ [ 390, 480, 4, 6 ], [ 480, 960, 10, 15 ], [ 960, 1050, 4, 6 ] ].each { |period| add_period(day, *period) } }
      render_block
      expect(table_rows.map { it["data-peak"] }).to eq([ "true", nil, "true" ])
    end
  end

  describe "其餘時段一列" do
    it "定時班次與每天的趟次" do
      route_day = store("2026-10-19").tap { add_period(it, 360, 1260, 10, 15) }
      add_departures(route_day, 1260, 1290)
      add_trip(route_day, "21:30")
      render_block
      expect(row_texts(table_rows.last)).to eq([ "其餘時段", "定時 21:00、21:30", "每天 1.0 趟", "每天 0.0 趟", "1", "—" ])
    end

    it "定時班次很多：寫班數與頭尾" do
      add_departures(store("2026-10-19"), *(0...37).map { 320 + (it * 30) })
      render_block
      expect(row_texts(table_rows.last)[1]).to eq("定時 37 班（05:20 到 23:20）")
    end

    it "沒有定時班次、只有時段外的趟次：定時那一格是 —" do
      route_day = store("2026-10-19").tap { add_period(it, 360, 1260, 10, 15) }
      add_trip(route_day, "21:30")
      render_block
      expect(row_texts(table_rows.last)[1]).to eq("—")
    end

    it "什麼都沒有：沒有這一列" do
      store("2026-10-19").tap { add_period(it, 360, 1260, 10, 15) }
      render_block
      expect(table_rows.size).to eq(1)
    end
  end

  describe "成員路線" do
    it "一列寫名字與它的定時班次" do
      add_departures(store("2026-10-19"), *(0...37).map { 320 + (it * 30) }, route_id: 9050)
      render_block
      member = table_rows.last
      expect([ member["data-member"], row_texts(member).first(2) ]).to eq([ "9050", [ "測試幹線經己站", "定時 37 班（05:20 到 23:20）" ] ])
    end

    it "成員路線有班距：一個時段一列，前面寫名字" do
      store("2026-10-19").tap { add_period(it, 360, 420, 4, 6, route_id: 9050) }
      render_block
      expect(row_texts(table_rows.first).first(2)).to eq([ "測試幹線經己站 06:00–07:00", "4–6 分" ])
    end

    it "成員路線的公告改過：各列寫哪幾天" do
      add_departures(store("2026-10-19"), 420, route_id: 9050)
      add_departures(store("2026-10-20"), 480, route_id: 9050)
      render_block
      expect(table_rows.map { row_texts(it).first }).to eq([ "測試幹線經己站（10-19）", "測試幹線經己站（10-20）" ])
    end
  end

  describe "假日" do
    it "假日的時段接在最後，前面寫假日" do
      store("2026-10-19").tap { add_period(it, 360, 420, 4, 6) }
      store("2026-10-25", day_type: "holiday").tap { add_period(it, 360, 1320, 15, 20) }
      render_block
      expect(table_rows.map { row_texts(it).first }).to eq([ "06:00–07:00", "假日 06:00–22:00" ])
    end

    it "假日的時段不標尖峰" do
      store("2026-10-25", day_type: "holiday").tap { add_period(it, 360, 1320, 15, 20) }
      render_block
      expect(table_rows.first["data-peak"]).to be_nil
    end

    it "第一個假日的列跟平日隔開" do
      store("2026-10-19").tap { add_period(it, 360, 420, 4, 6) }
      store("2026-10-25", day_type: "holiday").tap { add_period(it, 360, 1320, 15, 20) }
      render_block
      expect(table_rows.last[:class]).to include("sep")
    end
  end

  describe "公告改過的月份" do
    before do
      store("2026-10-19").tap { add_period(it, 390, 480, 4, 6) }
      store("2026-10-20").tap { add_period(it, 390, 480, 4, 6) }
      store("2026-10-27").tap { add_period(it, 390, 480, 8, 10) }
      render_block
    end

    it "每個版本一張表" do
      expect(page.all("[data-schedule-table]").size).to eq(2)
    end

    it "每張表的標題寫哪幾天，連續的併起來" do
      expect(page.all("[data-version-title]").map(&:text)).to eq([ "10-19 到 10-20", "10-27" ])
    end

    it "每張表用自己的班距" do
      expect(page.all("[data-schedule-table]").map { it.find("tbody tr td:nth-child(2)").text }).to eq([ "4–6 分", "8–10 分" ])
    end
  end

  it "公告沒改過：一張表，沒有標題" do
    store("2026-10-19").tap { add_period(it, 390, 480, 4, 6) }
    render_block
    expect([ page.all("[data-schedule-table]").size, page.all("[data-version-title]").size ]).to eq([ 1, 0 ])
  end

  describe "圖" do
    before { stub_cycle(182.2) }

    let(:route_day) { store("2026-10-19").tap { |day| [ [ 390, 480, 4, 6 ], [ 480, 960, 10, 15 ] ].each { |period| add_period(day, *period) } } }

    it "兩張圖：每小時發車與路上的車" do
      add_trip(route_day, "06:40", minutes: 40)
      render_block
      expect(page.all("[data-schedule-chart]", visible: :all).map { it["data-schedule-chart"] }).to eq(%w[departures vehicles])
    end

    it "發車那張有去程與返程兩條線" do
      add_trip(route_day, "06:40", minutes: 40)
      render_block
      expect(page.all("[data-schedule-chart='departures'] [data-series]", visible: :all).map { it["data-series"] }).to eq(%w[go back])
    end

    it "公告換算的色塊與尖峰的標註" do
      add_trip(route_day, "06:40", minutes: 40)
      render_block
      chart = page.find("[data-schedule-chart='departures']", visible: :all)
      expect([ chart.all("[data-band]", visible: :all).size, chart.find("[data-chart-note]", visible: :all).text ]).to eq([ 2, "公告 4–6 分一班" ])
    end

    it "路上的車那張的色塊是照公告要幾台，標註也是" do
      add_trip(route_day, "06:40", minutes: 40)
      render_block
      chart = page.find("[data-schedule-chart='vehicles']", visible: :all)
      expect(chart.find("[data-chart-note]", visible: :all).text).to eq("照公告 30–46 台")
    end

    it "固定班距與相同上下界的所需車數都畫出公告線" do
      add_period(route_day, 1020, 1440, 30, 30)
      add_trip(route_day, "17:00", minutes: 60)
      render_block
      expect(page.all("[data-schedule-chart] line[data-band]", visible: :all).size).to eq(2)
    end

    describe "只有 06 時與 09 時有趟次" do
      before do
        %w[06:00 09:00].each { |clock| [ 0, 1 ].each { |go_back| add_trip(route_day, clock, minutes: 60, go_back:, bus_id: "TEST-#{clock}-#{go_back}") } }
        render_block
      end

      %w[go back].each do |series|
        it "#{series} 的發車線在 07 與 08 時回到零" do
          expect(chart_points("departures", series)).to eq([ [ 6.5, 1.0 ], [ 7.5, 0.0 ], [ 8.5, 0.0 ], [ 9.5, 1.0 ] ])
        end
      end

      it "路上的車在 07 與 08 時也是零" do
        expect(chart_points("vehicles", "road")).to eq([ [ 6.5, 2.0 ], [ 7.5, 0.0 ], [ 8.5, 0.0 ], [ 9.5, 2.0 ] ])
      end
    end

    it "圖例寫週期中位數" do
      add_trip(route_day, "06:40", minutes: 40)
      render_block
      expect(page.find("[data-vehicles-legend]").text).to include("週期中位數 182 分鐘")
    end

    it "沒有平日的趟次：不畫圖" do
      route_day
      render_block
      expect(page).to have_no_css("[data-schedule-chart]", visible: :all)
    end
  end

  it "說明寫最新一天的快照" do
    store("2026-10-19")
    store("2026-10-20")
    render_block
    expect(page.find("[data-schedule-lead]").text).to include("GetSemiTimeTable，2026-10-20 的快照")
  end

  it "區塊標記是 schedule" do
    render_block
    expect(page).to have_css("section[data-card-section='schedule']")
  end
end
