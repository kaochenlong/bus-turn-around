module RoutePage
  # The timetable checked against the measured trips, as in the requirement
  # "Overrun table against the measured trips": for each percentile the timetable
  # offers, every trip with a run time of the covered days is compared with
  # the planned run time it would have had at that percentile, and its overrun
  # is the excess, zero when there is none. Trips are judged one by one; a late
  # trip's effect on the next departure is not followed.
  class TimetableOverruns
    # Shares are fractions of every trip with a run time; the median is over
    # the trips that overran, to one decimal, nil when none did.
    Row = Data.define(:percentile, :overrun_share, :exhausted_share, :median_overrun)

    # buffer: the rest minutes an overrun has to reach to count as exhausting
    # the rest. The planned run times are read from the given PlannedRunTimes
    # when the page already has one, so the query runs once.
    def initialize(route_days, buffer:, run_times: PlannedRunTimes.new(route_days, percentile: PlannedRunTimes::DEFAULT_PERCENTILE))
      @ids = route_days.ids
      @buffer = buffer
      @run_times = run_times
    end

    # One row per offered percentile, in order.
    def rows = PlannedRunTimes::PERCENTILES.map { row(it) }

    private

    def row(percentile)
      overruns = trips.map { |go_back, hour, minutes| [ minutes - @run_times.minutes_at(go_back, hour, percentile).first, 0 ].max }
      late = overruns.select(&:positive?)
      Row.new(percentile:, overrun_share: share(late.size), exhausted_share: share(late.count { it >= @buffer }), median_overrun: median(late))
    end

    def share(count) = trips.empty? ? nil : count.fdiv(trips.size)

    def median(values)
      return if values.empty?

      sorted = values.sort
      middle = sorted.size / 2
      (sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0).round(1)
    end

    # [direction, Taipei hour of the start, run time in minutes] of every trip
    # with a run time, the trips of the run-time spec.
    def trips
      @trips ||= Trip.where(route_day_id: @ids, completeness: "complete", start_from_arrival: false, end_from_departure: false)
                     .pluck(:go_back, Arel.sql(HOUR_SQL), Arel.sql(MINUTES_SQL))
    end

    HOUR_SQL = "CAST(extract(hour FROM start_time AT TIME ZONE 'Asia/Taipei') AS integer)".freeze
    MINUTES_SQL = "CAST(extract(epoch FROM end_time - start_time) / 60 AS double precision)".freeze
    private_constant :HOUR_SQL, :MINUTES_SQL
  end
end
