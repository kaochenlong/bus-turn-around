# frozen_string_literal: true

require "rails_helper"

RSpec.describe CycleTableComponent, type: :component do
  let(:route_day) do
    create(:route_day)
  end

  # The nature of the end where direction 0 trips end and of the one where
  # direction 1 trips end.
  def route_ends(outbound, inbound) = RoutePage::Ends.from_config({ 0 => outbound, 1 => inbound }, route_id: 9001)

  # The component's own translation of a key, read from its file: sidecar
  # translations are not in the global I18n backend.
  def sidecar(key) = YAML.load_file(Rails.root.join("app/components/cycle_table_component.yml"), aliases: true).dig("tw", key)

  def at(time, on) = Time.zone.parse("#{on.day} #{time}")

  # The clock time `minutes` after the clock time `time`.
  def later(time, minutes) = (Time.zone.parse("2026-10-19 #{time}") + minutes.minutes).strftime("%H:%M")

  # A trip of `bus_id` on the stored day; other attributes default to a
  # complete direction 0 trip with an observed departure and arrival.
  def trip(start, finish, bus_id, go_back: 0, on: route_day, **attributes)
    on.trips.create!({ bus_id:, path_attribute_id: 9001, go_back:, band: "other", start_time: at(start, on), end_time: at(finish, on),
                       first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                       start_from_arrival: false, end_from_departure: false }.merge(attributes))
  end

  def layover(end_time, next_start, bus_id, go_back: 0) = route_day.layovers.create!(bus_id:, go_back:, end_time: at(end_time, route_day),
                                                                                       next_start_time: at(next_start, route_day))

  # A round trip of `minutes` by `bus_id` leaving at `start`. With `stay`, also
  # the back trip before it, which ended `stay` minutes before `start`, so the
  # trips make a cycle of `stay` + `minutes` as well.
  def loop_of(bus_id, start, minutes, stay: nil)
    trip(later(start, -stay - 50), later(start, -stay), bus_id, go_back: 1).then { layover(later(start, -stay), start, bus_id, go_back: 1) } if stay
    trip(start, later(start, 40), bus_id)
    layover(later(start, 40), later(start, 50), bus_id)
    trip(later(start, 50), later(start, minutes), bus_id, go_back: 1)
  end

  def render_block(ends: route_ends("stop", "stop"), days: [ route_day ])
    render_inline(described_class.new(cycles: RoutePage::Cycles.new(RouteDay.where(id: days.map(&:id)).order(:day), ends:)))
  end

  # A cell's own text, without the small sample label inside it.
  def cell_text(cell) = cell.xpath("./text()").text.squish

  # The rows of a measure's table as their cells; the all-day row starts with
  # :total in place of its label.
  def table_rows(rendered, measure)
    rendered.css("[data-measure=#{measure}] tbody tr").map do |row|
      cells = row.css("td").map { cell_text(it) }
      row.key?("data-total") ? [ :total, *cells.drop(1) ] : cells
    end
  end

  # Whether each row of a measure's table is marked as a small sample, and
  # whether it says so.
  def small_sample_marks(rendered, measure)
    rendered.css("[data-measure=#{measure}] tbody tr").map { [ it.key?("data-small-sample"), it.text.include?(sidecar("small_sample")) ] }
  end

  # The numbers of the sentence above the tables.
  def headline_numbers(rendered) = rendered.css("[data-headline] [data-number]").map(&:text)

  describe "寫入的趟次與折返停留算出的兩張表：6 時 150、8 時 110 的來回，8 時 121 的週期" do
    before do
      loop_of("TEST-0001", "06:00", 150)
      loop_of("TEST-0002", "08:41", 110, stay: 11)
    end

    it "來回一趟那張：06 與 08 時各一列，全天 2 筆、p50 130.0、p85 144.0" do
      expect(table_rows(render_block, "round_trip")).to eq([ %w[06 1 150.0 150.0], %w[08 1 110.0 110.0], [ :total, "2", "130.0", "144.0" ] ])
    end

    it "週期那張：只有 08 時一列，全天 1 筆、p10 與 p50 都是 121.0" do
      expect(table_rows(render_block, "cycle")).to eq([ %w[08 1 121.0 121.0], [ :total, "1", "121.0", "121.0" ] ])
    end

    it "筆數少於 5 的列都標成樣本少，並在筆數旁寫出來" do
      rendered = render_block
      expect([ small_sample_marks(rendered, "round_trip"), small_sample_marks(rendered, "cycle") ]).to eq([ [ [ true, true ] ] * 3, [ [ true, true ] ] * 2 ])
    end
  end

  describe "全天那一列與白話句子" do
    def row(hour, round_trips, cycles) = RoutePage::Cycles::Row.new(hour:, n_round_trips: round_trips.first, round_trip_percentiles: round_trips.last,
                                                                    n_cycles: cycles.first, cycle_percentiles: cycles.last)

    def render_summary(total, rows: [])
      cycles = instance_double(RoutePage::Cycles, rows:, total:, any_round_trips?: true, first_stop_name: "甲站", last_stop_name: "戊站",
                                                  far_end_stopping?: false)
      render_inline(described_class.new(cycles:))
    end

    # The percentile cells of the all-day row of each table.
    def total_percentiles(rendered) = %w[round_trip cycle].flat_map { table_rows(rendered, it).last.drop(2) }

    it "句子裡的數字跟全天那一列的格子一字不差：151.3、169.6、146.8、181.6" do
      rendered = render_summary(row(nil, [ 106, [ 151.3, 169.6 ] ], [ 101, [ 146.8, 181.6 ] ]))
      expect([ headline_numbers(rendered), total_percentiles(rendered) ]).to eq([ %w[151.3 169.6 146.8 181.6] ] * 2)
    end

    it "同一列兩個量各自判斷樣本少：來回 5 筆不標，週期 4 筆標" do
      rendered = render_summary(row(nil, [ 5, [ 120.0, 130.0 ] ], [ 4, [ 125.0, 140.0 ] ]), rows: [ row(7, [ 5, [ 120.0, 130.0 ] ], [ 4, [ 125.0, 140.0 ] ]) ])
      expect([ small_sample_marks(rendered, "round_trip"), small_sample_marks(rendered, "cycle") ]).to eq([ [ [ false, false ] ] * 2, [ [ true, true ] ] * 2 ])
    end
  end

  it "有來回、沒有週期：句子只寫來回的 p50 與 p85，週期那張只有全天一列、0 筆、百分位數是 —" do
    loop_of("TEST-0001", "06:00", 150)
    rendered = render_block
    expect([ headline_numbers(rendered), table_rows(rendered, "cycle") ]).to eq([ %w[150.0 150.0], [ [ :total, "0", "—", "—" ] ] ])
  end

  it "只有一趟漏了末站、沒有折返停留：寫出沒有算得出來的來回，有說明，沒有句子、表格與切換" do
    trip("06:00", "06:40", "TEST-0001", completeness: "missing_end")
    block = render_block.at_css("section[data-section=cycles]")
    expect([ block.css("[data-stops]").size, block.css("[data-no-round-trips]").size, block.css("[data-headline], table, [data-measure-switch]").size ]).to eq([ 1, 1, 0 ])
  end

  it "一筆 6 時 150 分鐘的來回，沒有 JS 時：一個帶 x-cloak 的切換，兩張表都在、都沒有藏起來的 class" do
    loop_of("TEST-0001", "06:00", 150)
    rendered = render_block
    expect([ rendered.css("[data-measure-switch]").map { it.key?("x-cloak") }, %w[round_trip cycle].map { table_rows(rendered, it) }, rendered.css("[data-measure]").map { it.classes & %w[hidden max-sm:hidden] } ])
      .to eq([ [ true ], [ [ %w[06 1 150.0 150.0], [ :total, "1", "150.0", "150.0" ] ], [ [ :total, "0", "—", "—" ] ] ], [ [], [] ] ])
  end

  describe "說明裡的站名" do
    it "涵蓋 2026-10-19 與 10-20，取最新的 10-20：從甲站發車、回到戊站" do
      second_day = create(:route_day, day: Date.new(2026, 10, 20))
      route_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "乙站" }, { go_back: 1, seq: 9, stop_name: "丁站" } ])
      second_day.stops.create!([ { go_back: 0, seq: 0, stop_name: "甲站" }, { go_back: 1, seq: 9, stop_name: "戊站" } ])
      note = render_block(days: [ route_day, second_day ]).at_css("[data-stops]")
      expect([ note["data-first-stop"], note["data-last-stop"], note.css("[data-stop]").map(&:text).uniq ]).to eq([ "甲站", "戊站", %w[甲站 戊站] ])
    end

    it "最新一天沒有站牌（之前寫入的資料）：說明用起站與末站代替站名，不帶站名的屬性" do
      note = render_block.at_css("[data-stops]")
      expect([ note.key?("data-first-stop"), note.key?("data-last-stop"), note.css("[data-stop]").map(&:text).uniq ])
        .to eq([ false, false, [ sidecar("first_stop_fallback"), sidecar("last_stop_fallback") ] ])
    end

    it "兩端都停車：說明多一句，另一端的停留是休息" do
      expect(render_block(ends: route_ends("stop", "stop")).css("[data-stops] [data-far-end-rest]").size).to eq(1)
    end

    it "前段結束的那一端直接折返：說明沒有那一句" do
      expect(render_block(ends: route_ends("pass_through", "stop")).css("[data-far-end-rest]").size).to eq(0)
    end
  end
end
