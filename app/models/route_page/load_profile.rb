module RoutePage
  # The load profile pooled over the given route days, as in the load-profile
  # spec: per direction, time band and stop with a count, the number of trips,
  # the median and the p90 of the on-board count, kept to one decimal. Stop
  # names come from the latest of the days.
  class LoadProfile
    UPPER_LEVEL = 0.9

    Row = Data.define(:go_back, :band, :seq, :stop_name, :n_trips, :median, :p90)
    Stop = Data.define(:go_back, :seq, :stop_name)

    def initialize(route_days)
      @ids = route_days.ids
      @latest_id = route_days.order(day: :desc).pick(:id)
    end

    # The stops of the latest of the days, in direction and sequence order.
    def stops
      RouteDayStop.where(route_day_id: @latest_id).order(:go_back, :seq).pluck(:go_back, :seq, :stop_name)
                  .map { |go_back, seq, stop_name| Stop.new(go_back:, seq:, stop_name:) }
    end

    def rows
      RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ SQL, { ids: @ids, latest_id: @latest_id, upper: UPPER_LEVEL } ])).map do |row|
        Row.new(go_back: row["go_back"], band: row["band"], seq: row["seq"], stop_name: row["stop_name"],
                n_trips: row["n_trips"], median: row["median"].to_f, p90: row["p90"].to_f)
      end
    end

    SQL = <<~SQL.freeze
      SELECT t.go_back, t.band, c.seq, s.stop_name, count(*) AS n_trips,
             round(CAST(percentile_cont(0.5) WITHIN GROUP (ORDER BY c.on_board) AS numeric), 1) AS median,
             round(CAST(percentile_cont(:upper) WITHIN GROUP (ORDER BY c.on_board) AS numeric), 1) AS p90
      FROM trip_stop_counts c
      JOIN trips t ON t.id = c.trip_id
      LEFT JOIN route_day_stops s ON s.route_day_id = :latest_id AND s.go_back = t.go_back AND s.seq = c.seq
      WHERE t.route_day_id IN (:ids)
      GROUP BY t.go_back, t.band, c.seq, s.stop_name
      ORDER BY t.go_back, c.seq, t.band
    SQL
    private_constant :SQL
  end
end
