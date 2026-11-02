# frozen_string_literal: true

# The published schedule against what was measured, as in the monthly-card spec: two
# charts over the weekday hours and a table per version of the schedule. Public data
# has no approved trips or vehicle numbers, so nothing here says that a departure
# was missed, or why the two differ.
class MonthCardScheduleComponent < MonthCardComponent
  DEPARTURES_HEIGHT = 214
  VEHICLES_HEIGHT = 186
  # An hour before this belongs to the night before; the charts show the day.
  CHART_FIRST_HOUR = 5
  CHART_EARLIEST_HOUR = 4
  # A list of scheduled departures longer than this is its count and its two ends.
  LISTED_DEPARTURES = 8

  Table = Data.define(:title, :rows)
  # A row of scheduled departures and trips has its text in headway and no per_hour.
  Row = Data.define(:set, :label, :headway, :per_hour, :outbound, :inbound, :on_road, :needed, :peak, :member_id)

  Chart = MonthCardHourChartComponent

  def tables
    weekday, holiday = tables_of(:weekday), tables_of(:holiday)
    return weekday + holiday if weekday.size > 1 || holiday.size > 1

    [ Table.new(title: nil, rows: (weekday + holiday).flat_map(&:rows)) ].select { it.rows.any? }
  end

  # Whether this row starts the holidays, after the weekdays in the same table.
  def starts_holidays?(rows, index) = index.positive? && rows[index].set == :holiday && rows[index - 1].set == :weekday

  def snapshot_day = month_card.latest_published_schedule_day&.iso8601 || NONE

  def charts? = hours.any?

  def departures_chart
    Chart.new(aria_label: t(".departures_aria"), height: DEPARTURES_HEIGHT, first_hour:, last_hour: 24, ticks: ticks(departure_values + periods.map(&:per_hour_high)),
              series: [ departure_series("go", 0, Chart::SERIES_FIRST), departure_series("back", 1, Chart::SERIES_SECOND) ],
              bands: periods.map { Chart::Band.new(from_hour: it.start_minute / 60.0, to_hour: it.end_minute / 60.0, low: it.per_hour_low, high: it.per_hour_high) },
              notes: peaks.map { Chart::Note.new(hour: middle_hour(it), value: it.per_hour_high, text: t(".departures_note", headway: headway_span(it))) })
  end

  def vehicles_chart
    needed = periods.select(&:needed_low)
    Chart.new(aria_label: t(".vehicles_aria"), height: VEHICLES_HEIGHT, first_hour:, last_hour: 24, ticks: ticks(hours.map(&:on_road) + needed.map(&:needed_high)),
              series: [ Chart::Series.new(key: "road", color: Chart::SERIES_FIRST, points: hours.map { [ it.hour + 0.5, it.on_road ] }) ],
              bands: needed.map { Chart::Band.new(from_hour: it.start_minute / 60.0, to_hour: it.end_minute / 60.0, low: it.needed_low, high: it.needed_high) },
              notes: needed.select { peaks.include?(it) }.map { Chart::Note.new(hour: middle_hour(it), value: it.needed_high, text: t(".vehicles_note", needed: span(it.needed_low, it.needed_high))) })
  end

  def outbound_legend = t(".direction_legend", direction: direction_name(0), first: stops(0).first, last: stops(0).last)

  def inbound_legend = t(".direction_legend", direction: direction_name(1), first: stops(1).first, last: stops(1).last)

  def needed_legend
    p50 = month_card.cycles(:weekday).total.cycle_percentiles.last
    p50 && t(".needed_legend", p50: whole(p50))
  end

  def any_needed? = periods.any?(&:needed_low)

  def any_periods? = periods.any?

  private

  def tables_of(set)
    schedule = month_card.schedule(set)
    tables = schedule.versions.map { |version| Table.new(title: version_title(version.days, set), rows: version_rows(version, set)) }
    return tables if tables.empty?

    [ *tables[0..-2], tables.last.with(rows: tables.last.rows + member_rows(schedule, set)) ]
  end

  def version_rows(version, set)
    lowest = version.periods.map(&:low_minutes).min
    [ *version.periods.map { period_row(it, set, label: set_prefix(set), peak: set == :weekday && it.low_minutes == lowest) },
      version.others && others_row(version.others, set, label: "#{set_prefix(set)}#{t('.others')}") ].compact
  end

  def member_rows(schedule, set)
    split = schedule.member_rows.group_by(&:route_id).select { |_, rows| rows.size > 1 }.keys
    schedule.member_rows.flat_map do |member|
      name = "#{set_prefix(set)}#{member.route_name}#{"（#{days_label(member.days)}）" if split.include?(member.route_id)}"
      [ *member.periods.map { period_row(it, set, label: "#{name} ", member_id: member.route_id) },
        member.others && others_row(member.others, set, label: name, member_id: member.route_id) ].compact
    end
  end

  def period_row(period, set, label:, peak: false, member_id: nil)
    Row.new(set:, label: "#{label}#{clock(period.start_minute)}–#{clock(period.end_minute)}", headway: t(".headway", headway: headway_span(period)),
            per_hour: span(period.per_hour_low.round, period.per_hour_high.round), outbound: decimal(period.departures_per_hour.fetch(0)),
            inbound: decimal(period.departures_per_hour.fetch(1)), on_road: whole(period.on_road), needed: span(period.needed_low, period.needed_high), peak:, member_id:)
  end

  def others_row(others, set, label:, member_id: nil)
    Row.new(set:, label:, headway: departures_text(others.departures), per_hour: nil, outbound: t(".per_day", trips: decimal(others.trips_per_day.fetch(0))),
            inbound: t(".per_day", trips: decimal(others.trips_per_day.fetch(1))), on_road: whole(others.on_road), needed: NONE, peak: false, member_id:)
  end

  def departures_text(minutes)
    return NONE if minutes.empty?
    return t(".departures_listed", times: minutes.map { clock(it) }.join("、")) if minutes.size <= LISTED_DEPARTURES

    t(".departures_counted", count: minutes.size, first: clock(minutes.first), last: clock(minutes.last))
  end

  def set_prefix(set) = set == :holiday ? "#{t('.holiday')} " : ""

  def version_title(days, set) = "#{set_prefix(set)}#{days_label(days)}"

  # The days of a version, consecutive ones as a stretch.
  def days_label(days)
    days.slice_when { |earlier, later| later != earlier + 1 }.map do |stretch|
      stretch.one? ? stretch.first.strftime("%m-%d") : "#{stretch.first.strftime('%m-%d')} 到 #{stretch.last.strftime('%m-%d')}"
    end.join("、")
  end

  def headway_span(period) = span(period.low_minutes, period.high_minutes)

  def middle_hour(period) = (period.start_minute + period.end_minute) / 120.0

  def periods = @periods ||= month_card.schedule(:weekday).versions.last&.periods.to_a

  def peaks = @peaks ||= month_card.peak_periods(:weekday)

  # ScheduleComparison omits all-zero hours; keep those between measured hours so
  # the chart does not join two active hours across a gap with no trips.
  def hours
    @hours ||= begin
      measured = month_card.schedule(:weekday).hours.select { it.hour >= CHART_EARLIEST_HOUR }.index_by(&:hour)
      if measured.empty?
        []
      else
        (measured.keys.min..measured.keys.max).map do |hour|
          measured.fetch(hour) { RoutePage::ScheduleComparison::Hour.new(hour:, departures: { 0 => 0.0, 1 => 0.0 }, on_road: 0.0) }
        end
      end
    end
  end

  def first_hour = [ CHART_FIRST_HOUR, hours.map(&:hour).min ].compact.min

  def departure_values = hours.flat_map { it.departures.values }

  def departure_series(key, go_back, color)
    Chart::Series.new(key:, color:, points: hours.map { [ it.hour + 0.5, it.departures.fetch(go_back) ] })
  end

  def ticks(values) = Chart.ticks_for(0, values.max.to_f.ceil)

  def stops(go_back) = month_card.first_and_last_stop(go_back).map { it || NONE }
end
