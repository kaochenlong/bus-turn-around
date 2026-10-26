module RoutePage
  # The stop speeds over the given route days, as in the stop-to-stop-speed
  # spec. A direction's legs come from the page route's placed stops of the
  # latest of the days on which that direction has any, each leg running from a
  # placed stop to the next one. The stored rows of every day pool per
  # direction, leg and band, and a cell's speed is its metres over its seconds;
  # a row whose leg is not a leg of that day does not count. A cell with fewer
  # than RunTimes::SMALL_SAMPLE trips is a small sample: it has no level and
  # does not set the scale. A shaded cell's level is the ceiling of LEVELS
  # times its seconds per metre over the largest of its direction, compared as
  # rationals so that a value on a boundary takes the lighter level; a shaded
  # cell of no metres is the darkest level and does not set the scale. It reads
  # two queries, each once.
  class StopSpeeds
    BANDS = %w[morning_peak daytime evening_peak other].freeze
    DIRECTIONS = [ 0, 1 ].freeze
    LEVELS = 4

    # level_ranges: per level from 1 to 4, [from, to] in km/h to one decimal,
    # nil for an open end; empty without a shaded cell of some metres.
    Direction = Data.define(:go_back, :legs, :level_ranges)
    # cells: per band, a Cell.
    Leg = Data.define(:seq, :from_name, :to_name, :meters, :cells)
    Cell = Data.define(:kmh, :n_trips, :small_sample, :level)

    # The pooled metres in tenths, seconds and trips of one direction, leg and band.
    Sum = Data.define(:tenths, :seconds, :n_trips) do
      def kmh = Rational(tenths * 36, seconds * 100)

      def shaded? = n_trips >= RunTimes::SMALL_SAMPLE

      # Seconds per metre; a cell of no metres has none.
      def pace = tenths.zero? ? nil : Rational(seconds * 10, tenths)
    end

    def initialize(route_days)
      @ids = route_days.ids
    end

    def available? = sums.any?

    def directions = @directions ||= DIRECTIONS.map { direction(it) }

    private

    def direction(go_back)
      sums = Array(placed_stops[go_back]).each_cons(2).to_h { |from, _to| [ from.seq, BANDS.to_h { [ it, self.sums[[ go_back, from.seq, it ]] ] } ] }
      slowest = sums.values.flat_map(&:values).compact.select { it.shaded? && it.pace }.max_by(&:pace)
      legs = Array(placed_stops[go_back]).each_cons(2).map { |from, to| leg(from, to, sums.fetch(from.seq), slowest) }
      Direction.new(go_back:, legs:, level_ranges: slowest ? level_ranges(slowest.kmh) : [])
    end

    def leg(from, to, sums, slowest)
      cells = sums.transform_values { |sum| cell(sum, slowest) }
      Leg.new(seq: from.seq, from_name: from.stop_name, to_name: to.stop_name, meters: (to.shape_meters - from.shape_meters).round(1), cells:)
    end

    def cell(sum, slowest)
      return Cell.new(kmh: nil, n_trips: 0, small_sample: false, level: nil) unless sum

      Cell.new(kmh: sum.kmh.round(1).to_f, n_trips: sum.n_trips, small_sample: !sum.shaded?, level: level(sum, slowest))
    end

    def level(sum, slowest)
      return unless sum.shaded?
      return LEVELS unless sum.pace

      (LEVELS * sum.pace / slowest.pace).ceil.clamp(1, LEVELS)
    end

    # Level k holds the paces from (k - 1) / 4 to k / 4 of the slowest one,
    # that is the speeds from 4v / k to 4v / (k - 1) for the slowest speed v.
    def level_ranges(slowest_kmh)
      bounds = [ 4, 2, Rational(4, 3) ].map { (slowest_kmh * it).round(1).to_f }
      [ [ bounds[0], nil ], [ bounds[1], bounds[0] ], [ bounds[2], bounds[1] ], [ nil, bounds[2] ] ]
    end

    # The page route's placed stops of each direction, from the latest of the
    # days on which that direction has any, in sequence order.
    def placed_stops
      @placed_stops ||= RouteDayStop.find_by_sql([ STOPS_SQL, { ids: @ids } ]).group_by(&:go_back)
    end

    def sums
      @sums ||= RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ SUMS_SQL, { ids: @ids } ])).to_h do |row|
        [ row.values_at("go_back", "seq", "band"), Sum.new(tenths: row["tenths"].to_i, seconds: row["seconds"].to_i, n_trips: row["n_trips"]) ]
      end
    end

    STOPS_SQL = <<~SQL.freeze
      WITH latest AS (
        SELECT DISTINCT ON (s.go_back) s.go_back, s.route_day_id
        FROM route_day_stops s
        JOIN route_days d ON d.id = s.route_day_id
        WHERE s.route_day_id IN (:ids) AND s.route_id = d.route_id AND s.shape_meters IS NOT NULL
        ORDER BY s.go_back, d.day DESC
      )
      SELECT s.go_back, s.seq, s.stop_name, s.shape_meters
      FROM route_day_stops s
      JOIN latest l ON l.route_day_id = s.route_day_id AND l.go_back = s.go_back
      JOIN route_days d ON d.id = s.route_day_id
      WHERE s.route_id = d.route_id AND s.shape_meters IS NOT NULL
      ORDER BY s.go_back, s.seq
    SQL

    SUMS_SQL = <<~SQL.freeze
      SELECT t.go_back, ss.seq, ss.band, round(CAST(sum(ss.meters) * 10 AS numeric)) AS tenths, sum(ss.seconds) AS seconds, count(*) AS n_trips
      FROM trip_stop_speeds ss
      JOIN trips t ON t.id = ss.trip_id
      WHERE t.route_day_id IN (:ids)
      GROUP BY t.go_back, ss.seq, ss.band
    SQL
    private_constant :STOPS_SQL, :SUMS_SQL
  end
end
