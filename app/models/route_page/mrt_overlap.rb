module RoutePage
  # MRT overlap over the given route days, as in the mrt-overlap spec. A stop
  # is near the MRT when its nearest entrance is at most a threshold away. Per
  # direction: the share of stops near the MRT at each threshold. At
  # STRETCH_THRESHOLD: runs of at least two adjacent near stops, each with the
  # on-board counts of every trip at its stops pooled per time band. Stops come
  # from the latest of the days. Nothing here compares a share with a review
  # threshold.
  class MrtOverlap
    THRESHOLDS = [ 300, 500, 800 ].freeze
    STRETCH_THRESHOLD = 500
    UPPER_LEVEL = 0.9

    Direction = Data.define(:go_back, :n_stops, :shares)
    Stretch = Data.define(:go_back, :first_seq, :last_seq, :first_stop, :last_stop, :n_stops, :loads)

    def initialize(route_days)
      @ids = route_days.ids
      @latest = route_days.order(day: :desc).first
    end

    def mrt_exits_day = @latest&.mrt_exits_day

    # Days loaded before stops carried distances have to be loaded again.
    def needs_reload? = stops.empty? || stops.any? { it.nearest_exit_meters.nil? }

    def directions
      stops.group_by(&:go_back).map do |go_back, direction_stops|
        shares = THRESHOLDS.to_h { |meters| [ meters, direction_stops.count { near?(it, meters) }.fdiv(direction_stops.size) ] }
        Direction.new(go_back:, n_stops: direction_stops.size, shares:)
      end
    end

    def stretches
      stops.group_by(&:go_back).flat_map do |go_back, direction_stops|
        runs(direction_stops).map do |run|
          Stretch.new(go_back:, first_seq: run.first.seq, last_seq: run.last.seq, first_stop: run.first.stop_name,
                      last_stop: run.last.stop_name, n_stops: run.size, loads: loads(go_back, run.first.seq, run.last.seq))
        end
      end
    end

    private

    def stops
      @stops ||= @latest ? RouteDayStop.where(route_day_id: @latest.id).order(:go_back, :seq).to_a : []
    end

    def near?(stop, meters) = stop.nearest_exit_meters && stop.nearest_exit_meters <= meters

    # Runs of at least two stops with adjacent sequence numbers, all near.
    def runs(direction_stops)
      direction_stops.select { near?(it, STRETCH_THRESHOLD) }
                     .slice_when { |a, b| b.seq != a.seq + 1 }
                     .select { it.size >= 2 }
    end

    def loads(go_back, first_seq, last_seq)
      sql = RouteDay.sanitize_sql_array([ LOADS_SQL, { ids: @ids, go_back:, first_seq:, last_seq:, upper: UPPER_LEVEL } ])
      RouteDay.connection.select_all(sql).map do |row|
        { band: row["band"], n_trips: row["n_trips"], median: row["median"].to_f, p90: row["p90"].to_f }
      end
    end

    LOADS_SQL = <<~SQL.freeze
      SELECT t.band, count(DISTINCT t.id) AS n_trips,
             round(CAST(percentile_cont(0.5) WITHIN GROUP (ORDER BY c.on_board) AS numeric), 1) AS median,
             round(CAST(percentile_cont(:upper) WITHIN GROUP (ORDER BY c.on_board) AS numeric), 1) AS p90
      FROM trip_stop_counts c
      JOIN trips t ON t.id = c.trip_id
      WHERE t.route_day_id IN (:ids) AND t.go_back = :go_back AND c.seq BETWEEN :first_seq AND :last_seq
      GROUP BY t.band
      ORDER BY t.band
    SQL
    private_constant :LOADS_SQL
  end
end
