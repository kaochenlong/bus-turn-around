# frozen_string_literal: true

# Round trips and cycles of the weekdays by the hour the lead trip left, as in the
# monthly-card spec: where the tightest cycles are as short as a round trip, a
# vehicle gets back to the stopping end with no spare time.
class MonthCardCyclesComponent < MonthCardComponent
  HEIGHT = 136
  MIN_VALUES = RoutePage::MonthFindings::MIN_HOUR_VALUES

  Chart = MonthCardHourChartComponent

  def chart? = charted_rows.any?

  def chart
    values = round_trip_points.map(&:last) + cycle_points.map(&:last)
    hours = charted_rows.map(&:hour)
    Chart.new(aria_label: t(".aria"), height: HEIGHT, first_hour: hours.min, last_hour: hours.max + 1, ticks: Chart.ticks_for(values.min.floor, values.max.ceil),
              series: [ Chart::Series.new(key: "round-trip", color: Chart::SERIES_FIRST, points: round_trip_points),
                        Chart::Series.new(key: "cycle", color: Chart::SERIES_SECOND, points: cycle_points) ],
              shaded_hours: rows.select { RoutePage::MonthFindings.tight?(it) }.map(&:hour))
  end

  def first_stop = cycles.first_stop_name || NONE

  def last_stop = cycles.last_stop_name || NONE

  private

  def cycles = month_card.cycles(:weekday)

  def rows = cycles.rows

  def charted_rows = rows.select { it.n_round_trips >= MIN_VALUES || it.n_cycles >= MIN_VALUES }

  def round_trip_points = rows.select { it.n_round_trips >= MIN_VALUES }.map { [ it.hour + 0.5, it.round_trip_percentiles.first ] }

  def cycle_points = rows.select { it.n_cycles >= MIN_VALUES }.map { [ it.hour + 0.5, it.cycle_percentiles.first ] }
end
