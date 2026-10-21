module RoutePage
  # Run times over the given route days, as in the run-time spec: complete
  # trips only, leaving out and counting those whose start comes from an
  # arrival or whose end comes from a departure. Grouped by direction and the
  # Taipei hour of the start, with p50, p85 and p95 interpolated linearly and
  # kept to one decimal. A group with fewer than SMALL_SAMPLE trips is marked.
  class RunTimes
    PERCENTILE_LEVELS = [ 0.5, 0.85, 0.95 ].freeze
    SMALL_SAMPLE = 5
    DIRECTIONS = [ 0, 1 ].freeze

    Row = Data.define(:go_back, :hour, :n_trips, :percentiles, :small_sample)

    def initialize(route_days)
      @trips = Trip.where(route_day: route_days, completeness: "complete")
    end

    def rows
      RouteDay.connection.select_all(sql).map do |row|
        Row.new(go_back: row["go_back"], hour: row["hour"], n_trips: row["n_trips"],
                percentiles: PERCENTILE_LEVELS.each_index.map { row["p#{it}"].to_f },
                small_sample: row["n_trips"] < SMALL_SAMPLE)
      end
    end

    # Excluded trips per direction; every direction is listed.
    def excluded
      counts = @trips.where("start_from_arrival OR end_from_departure").group(:go_back).count
      DIRECTIONS.to_h { [ it, counts.fetch(it, 0) ] }
    end

    private

    def sql
      percentiles = PERCENTILE_LEVELS.each_with_index.map do |level, index|
        "round(CAST(percentile_cont(#{level}) WITHIN GROUP (ORDER BY minutes) AS numeric), 1) AS p#{index}"
      end
      counted = @trips.where(start_from_arrival: false, end_from_departure: false)
                      .select("go_back, start_time, CAST(extract(epoch FROM end_time - start_time) / 60 AS double precision) AS minutes")
      <<~SQL
        SELECT go_back, CAST(extract(hour FROM start_time AT TIME ZONE 'Asia/Taipei') AS integer) AS hour,
               count(*) AS n_trips, #{percentiles.join(', ')}
        FROM (#{counted.to_sql}) counted
        GROUP BY 1, 2
        ORDER BY 1, 2
      SQL
    end
  end
end
