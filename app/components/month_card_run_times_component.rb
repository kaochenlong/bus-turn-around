# frozen_string_literal: true

# Run times of the weekdays per starting hour next to round trips and cycles, with
# the slowest stretches between two stops in the peaks, as in the monthly-card spec.
# A figure from few trips is shown apart, not left out.
class MonthCardRunTimesComponent < MonthCardComponent
  SMALL_SAMPLE = RoutePage::RunTimes::SMALL_SAMPLE

  # A count and two figures of an hour; small when the count is under SMALL_SAMPLE.
  Group = Data.define(:count, :first, :second) do
    def small? = count.positive? && count < SMALL_SAMPLE
  end
  Hour = Data.define(:hour, :outbound, :inbound, :round_trip, :cycle)

  def outbound_excluded = excluded.fetch(0)

  def inbound_excluded = excluded.fetch(1)

  # Which direction has the fewer trips counted, nil when none has.
  def fewer_direction
    return if outbound_excluded == inbound_excluded

    direction_name(outbound_excluded > inbound_excluded ? 0 : 1)
  end

  def hours
    run_rows = month_card.run_times(:weekday).rows
    cycle_rows = month_card.cycles(:weekday).rows
    (run_rows.map(&:hour) | cycle_rows.map(&:hour)).sort.map do |hour|
      runs = run_rows.select { it.hour == hour }
      cycle = cycle_rows.find { it.hour == hour }
      Hour.new(hour:, outbound: run_group(runs, 0), inbound: run_group(runs, 1), round_trip: round_trip_group(cycle), cycle: cycle_group(cycle))
    end
  end

  def total = month_card.cycles(:weekday).total

  def total_round_trip = round_trip_group(total)

  def total_cycle = cycle_group(total)

  def slow_legs = month_card.slow_legs.rows

  private

  def excluded = month_card.run_times(:weekday).excluded

  def run_group(runs, go_back)
    run = runs.find { it.go_back == go_back }
    run ? Group.new(count: run.n_trips, first: whole(run.percentiles[0]), second: whole(run.percentiles[1])) : empty_group
  end

  def round_trip_group(row)
    return empty_group unless row&.n_round_trips&.positive?

    Group.new(count: row.n_round_trips, first: whole(row.round_trip_percentiles[0]), second: whole(row.round_trip_percentiles[1]))
  end

  def cycle_group(row)
    return empty_group unless row&.n_cycles&.positive?

    Group.new(count: row.n_cycles, first: whole(row.cycle_percentiles[0]), second: whole(row.cycle_percentiles[1]))
  end

  def empty_group = Group.new(count: 0, first: NONE, second: NONE)
end
