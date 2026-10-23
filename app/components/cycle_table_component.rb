# frozen_string_literal: true

# Round trips and cycles by departure hour, one table for each with an
# all-day row, and a sentence built only from that row. Below 640 px wide one
# table shows at a time; without JavaScript both are there. Only numbers:
# nothing is marked as meeting a rule or coloured by its size.
class CycleTableComponent < ApplicationComponent
  # What each table reads from a row, in page order.
  MEASURES = {
    round_trip: { count: :n_round_trips, percentiles: :round_trip_percentiles, small_sample: :round_trip_small_sample? },
    cycle: { count: :n_cycles, percentiles: :cycle_percentiles, small_sample: :cycle_small_sample? }
  }.freeze

  def initialize(cycles:)
    @cycles = cycles
  end

  def measures = MEASURES.keys

  def any_round_trips? = @cycles.any_round_trips?

  # The hourly rows with a value of the measure, then the all-day row.
  def table_rows(measure) = [ *@cycles.rows.select { count(it, measure).positive? }, @cycles.total ]

  def count(row, measure) = row.public_send(MEASURES.fetch(measure).fetch(:count))

  def percentiles(row, measure) = row.public_send(MEASURES.fetch(measure).fetch(:percentiles))

  def small_sample?(row, measure) = row.public_send(MEASURES.fetch(measure).fetch(:small_sample))

  # p50 and p85, or p10 and p50: the column names of a measure's percentiles.
  def percentile_labels(measure) = RoutePage::Cycles::PERCENTILE_LEVELS.fetch(measure).map { "p#{(it * 100).round}" }

  def hour_label(row) = row.hour.nil? ? t(".all_day") : format("%02d", row.hour)

  # The note naming where a round trip leaves and returns, in words when the
  # latest day has no stops, with one more sentence when the far end is a
  # stopping end.
  def note
    t(".note_html", first_stop: stop_name(@cycles.first_stop_name, "first"), last_stop: stop_name(@cycles.last_stop_name, "last"),
                    far_end_rest: (tag.span(t(".far_end_rest"), data: { far_end_rest: true }) if @cycles.far_end_stopping?))
  end

  # The sentence, from the all-day row only and with the text of its cells;
  # only the round trip half when there is no cycle.
  def headline
    total = @cycles.total
    round_trip_p50, round_trip_p85 = total.round_trip_percentiles.map { number(it) }
    return t(".headline_round_trip_only_html", round_trip_p50:, round_trip_p85:) if total.n_cycles.zero?

    cycle_p10, cycle_p50 = total.cycle_percentiles.map { number(it) }
    t(".headline_html", round_trip_p50:, round_trip_p85:, cycle_p10:, cycle_p50:)
  end

  def note_data = { stops: true, first_stop: @cycles.first_stop_name, last_stop: @cycles.last_stop_name }

  private

  def stop_name(name, which) = tag.span(name || t(".#{which}_stop_fallback"), data: { stop: which })

  def number(value) = tag.span(minutes(value), data: { number: true })
end
