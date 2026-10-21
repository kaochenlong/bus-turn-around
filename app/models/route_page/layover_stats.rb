module RoutePage
  # Layovers per direction of the ending trip, pooled over the given route
  # days, as in the layover-metrics spec: count, p10, p50 and p90 interpolated
  # linearly and kept to one decimal, and the share under 15 minutes. Minutes
  # come from the two stored times. Each direction is named after its last
  # stop on the latest of the days, and has a row even without layovers.
  class LayoverStats
    PERCENTILE_LEVELS = [ 0.1, 0.5, 0.9 ].freeze
    SHORT_MINUTES = 15

    Row = Data.define(:go_back, :stop_name, :n_layovers, :percentiles, :short_share)

    def initialize(route_days)
      @ids = route_days.ids
      @latest_id = route_days.order(day: :desc).pick(:id)
    end

    def rows
      RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ sql, { ids: @ids, latest_id: @latest_id } ])).map do |row|
        Row.new(go_back: row["go_back"], stop_name: row["stop_name"], n_layovers: row["n_layovers"],
                percentiles: PERCENTILE_LEVELS.each_index.map { row["p#{it}"]&.to_f },
                short_share: row["short_share"])
      end
    end

    private

    def sql
      percentiles = PERCENTILE_LEVELS.each_with_index.map do |level, index|
        "round(CAST(percentile_cont(#{level}) WITHIN GROUP (ORDER BY m.minutes) AS numeric), 1) AS p#{index}"
      end
      <<~SQL
        WITH last_stops AS (
            SELECT DISTINCT ON (go_back) go_back, stop_name
            FROM route_day_stops
            WHERE route_day_id = :latest_id
            ORDER BY go_back, seq DESC
        ),
        minutes AS (
            SELECT go_back, CAST(extract(epoch FROM next_start_time - end_time) / 60 AS double precision) AS minutes
            FROM layovers
            WHERE route_day_id IN (:ids)
        )
        SELECT s.go_back, s.stop_name, count(m.minutes) AS n_layovers, #{percentiles.join(', ')},
               CAST(count(m.minutes) FILTER (WHERE m.minutes < #{SHORT_MINUTES}) AS double precision)
                 / nullif(count(m.minutes), 0) AS short_share
        FROM last_stops s
        LEFT JOIN minutes m ON m.go_back = s.go_back
        GROUP BY s.go_back, s.stop_name
        ORDER BY s.go_back
      SQL
    end
  end
end
