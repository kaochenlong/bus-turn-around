module HomePage
  # For each given route day and direction, the layovers ending at that
  # direction's last stop: their count and the share under 15 minutes, in one
  # statement for all the days. Minutes and threshold are the route page's
  # (RoutePage::LayoverStats), and so is the last stop: the page route's stop
  # with the highest sequence number, so a member route's stops do not count.
  # A direction without stops on that day has no row.
  class StopEndFigures
    Row = Data.define(:route_day_id, :go_back, :stop_name, :n_layovers, :short_share)

    # Route day records already read: the route Id of each day is passed to
    # the statement, which does not read route_days.
    def initialize(route_days)
      @route_day_ids = route_days.map(&:id)
      @route_ids = route_days.map(&:route_id)
    end

    # Ordered by route day and direction; without any route day, no statement.
    def rows
      @rows ||= @route_day_ids.empty? ? [] : select_rows
    end

    private

    def select_rows
      binds = { route_day_ids: @route_day_ids, route_ids: @route_ids }
      RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ sql, binds ])).map do |row|
        Row.new(route_day_id: row["route_day_id"], go_back: row["go_back"], stop_name: row["stop_name"], n_layovers: row["n_layovers"],
                short_share: row["short_share"])
      end
    end

    def sql
      <<~SQL
        WITH last_stops AS (
            SELECT DISTINCT ON (s.route_day_id, s.go_back) s.route_day_id, s.go_back, s.stop_name
            FROM route_day_stops s
            JOIN unnest(ARRAY[:route_day_ids]::bigint[], ARRAY[:route_ids]::integer[]) AS d(route_day_id, route_id)
              ON d.route_day_id = s.route_day_id AND d.route_id = s.route_id
            ORDER BY s.route_day_id, s.go_back, s.seq DESC
        ),
        minutes AS (
            SELECT route_day_id, go_back, #{RoutePage::LayoverStats::MINUTES_SQL} AS minutes
            FROM layovers
            WHERE route_day_id IN (:route_day_ids)
        )
        SELECT s.route_day_id, s.go_back, s.stop_name, count(m.minutes) AS n_layovers,
               #{RoutePage::LayoverStats::SHORT_SHARE_SQL} AS short_share
        FROM last_stops s
        LEFT JOIN minutes m ON m.route_day_id = s.route_day_id AND m.go_back = s.go_back
        GROUP BY s.route_day_id, s.go_back, s.stop_name
        ORDER BY s.route_day_id, s.go_back
      SQL
    end
  end
end
