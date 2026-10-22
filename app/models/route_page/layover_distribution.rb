module RoutePage
  # Layovers per direction of the ending trip, pooled over the given route
  # days and counted in the health card's bins: each bin includes its lower
  # bound and excludes the next one, the last bin is open-ended. The bounds
  # repeat layover_bin_lower_bounds of analysis/params.sql; the card
  # consistency spec keeps the two equal. Each direction is named after its
  # last stop and the first stop of the other direction, where the next trip
  # starts, on the latest of the days, and has counts even without layovers.
  class LayoverDistribution
    BIN_LOWER_BOUNDS = [ 0, 5, 10, 15, 30, 60 ].freeze

    Direction = Data.define(:go_back, :last_stop, :next_first_stop, :counts)

    def initialize(route_days)
      @ids = route_days.ids
      @latest_id = route_days.order(day: :desc).pick(:id)
    end

    def directions
      RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ sql, { ids: @ids, latest_id: @latest_id } ])).map do |row|
        Direction.new(go_back: row["go_back"], last_stop: row["last_stop"], next_first_stop: row["next_first_stop"],
                      counts: BIN_LOWER_BOUNDS.each_index.map { row["bin#{it}"] })
      end
    end

    private

    def sql
      bins = BIN_LOWER_BOUNDS.each_with_index.map do |lower, index|
        upper = BIN_LOWER_BOUNDS[index + 1]
        condition = upper ? "m.minutes >= #{lower} AND m.minutes < #{upper}" : "m.minutes >= #{lower}"
        "count(m.minutes) FILTER (WHERE #{condition}) AS bin#{index}"
      end
      <<~SQL
        WITH ends AS (
            SELECT go_back,
                   (array_agg(stop_name ORDER BY seq DESC))[1] AS last_stop,
                   (array_agg(stop_name ORDER BY seq))[1] AS first_stop
            FROM route_day_stops
            WHERE route_day_id = :latest_id
            GROUP BY go_back
        ),
        minutes AS (
            SELECT go_back, CAST(extract(epoch FROM next_start_time - end_time) / 60 AS double precision) AS minutes
            FROM layovers
            WHERE route_day_id IN (:ids)
        )
        SELECT e.go_back, e.last_stop, o.first_stop AS next_first_stop, #{bins.join(', ')}
        FROM ends e
        LEFT JOIN ends o ON o.go_back = 1 - e.go_back
        LEFT JOIN minutes m ON m.go_back = e.go_back
        GROUP BY e.go_back, e.last_stop, o.first_stop
        ORDER BY e.go_back
      SQL
    end
  end
end
