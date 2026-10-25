module RoutePage
  # The planned run time of a timetable trip, as in the timetable spec: the
  # chosen percentile of the run times, as the run-time spec defines them, of
  # the covered days' trips of the same direction departing in the same Taipei
  # hour, interpolated linearly and rounded half up to a whole minute. An hour
  # with fewer than RunTimes::SMALL_SAMPLE such trips falls back to the
  # direction's percentile over the whole day and says so. Every percentile
  # the timetable offers is read in the one query, so the overrun table can ask
  # for the others.
  class PlannedRunTimes
    PERCENTILES = (50..95).step(5).to_a.freeze
    DEFAULT_PERCENTILE = 85

    # The trips of one direction and hour, or of one direction over the day:
    # how many, and the whole minutes at every percentile.
    Group = Data.define(:n_trips, :minutes)

    attr_reader :percentile

    def initialize(route_days, percentile:)
      raise ArgumentError, "percentile #{percentile} is not one of #{PERCENTILES.join(', ')}" unless PERCENTILES.include?(percentile)

      @ids = route_days.ids
      @percentile = percentile
    end

    # [whole minutes, whether the hour fell back to the whole day], or nil when
    # the direction has no run time at all.
    def minutes(go_back, hour) = minutes_at(go_back, hour, percentile)

    # The same at another of the offered percentiles.
    def minutes_at(go_back, hour, percentile)
      all_day = groups[[ go_back, nil ]]
      return unless all_day

      hourly = groups[[ go_back, hour ]]
      return [ hourly.minutes.fetch(percentile), false ] if hourly && hourly.n_trips >= RunTimes::SMALL_SAMPLE

      [ all_day.minutes.fetch(percentile), true ]
    end

    # Whether the direction has any trip with a run time.
    def any?(go_back) = groups.key?([ go_back, nil ])

    private

    # Keyed by [go_back, hour], the whole day's row of a direction by
    # [go_back, nil].
    def groups
      @groups ||= RouteDay.connection.select_all(sql).to_h do |row|
        [ [ row["go_back"], row["hour"] ],
          Group.new(n_trips: row["n_trips"], minutes: PERCENTILES.to_h { [ it, row["p#{it}"].to_f.round ] }) ]
      end
    end

    # One row per direction and hour, and one per direction over every hour
    # (hour NULL), each with the count and every offered percentile.
    def sql
      percentiles = PERCENTILES.map { "percentile_cont(#{format('%.2f', it / 100.0)}) WITHIN GROUP (ORDER BY minutes) AS p#{it}" }
      counted = Trip.where(route_day_id: @ids, completeness: "complete", start_from_arrival: false, end_from_departure: false)
                    .select("go_back, CAST(extract(hour FROM start_time AT TIME ZONE 'Asia/Taipei') AS integer) AS hour, " \
                            "CAST(extract(epoch FROM end_time - start_time) / 60 AS double precision) AS minutes")
      <<~SQL
        SELECT go_back, hour, count(*) AS n_trips, #{percentiles.join(', ')}
        FROM (#{counted.to_sql}) counted
        GROUP BY GROUPING SETS ((go_back, hour), (go_back))
      SQL
    end
  end
end
