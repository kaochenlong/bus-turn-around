module RoutePage
  # The cost of a schedule buffer at every layover, as in the buffer-trade
  # spec: B minutes of rest (the page's buffer) after arriving D minutes later
  # than measured (the lateness), so every turnaround has to hold H = B + D
  # minutes. Only measured layovers at the stopping ends of the route count;
  # those at a pass-through end are not rest opportunities and are only
  # counted. The cost is a range from topping each layover up to H (lower) to
  # adding H to every layover (upper), in vehicle-hours per day and in added
  # vehicles in the busiest Taipei hour of the layovers' end times.
  class BufferTrade
    DEFAULT_MINUTES = 15
    MINUTES_RANGE = 0..20
    DEFAULT_LATE = 0
    LATE_RANGE = 0..20
    # Every minutes to hold the curve has a point for: the rest plus the
    # lateness, each up to 20.
    HOLD_RANGE = 0..(MINUTES_RANGE.max + LATE_RANGE.max)
    # Taipei hours of the layovers' end times: the whole day is the default of
    # the selected hours, whose first hour is one of FIRST_HOURS and last one
    # of LAST_HOURS, the first below the last.
    ALL_HOURS = 0...24
    FIRST_HOURS = 0..23
    LAST_HOURS = 1..24
    WHOLE_NUMBER = /\A\d+\z/

    # The rest minutes from the page's buffer parameter; a value the page does
    # not accept raises like a bad day or range.
    def self.minutes(param) = whole_minutes(param, default: DEFAULT_MINUTES, range: MINUTES_RANGE, name: "buffer")

    # The lateness minutes from the page's late parameter, checked like the
    # buffer.
    def self.late(param) = whole_minutes(param, default: DEFAULT_LATE, range: LATE_RANGE, name: "late")

    # The selected hours from the page's from and to parameters, as the Range
    # first...last; each one left out is the whole day's.
    def self.hour_range(first, last)
      from = first.blank? ? ALL_HOURS.begin : whole_number(first)
      to = last.blank? ? ALL_HOURS.end : whole_number(last)
      raise Coverage::InvalidParameter, "from, to: #{first}, #{last}" unless FIRST_HOURS.cover?(from) && LAST_HOURS.cover?(to) && from < to

      from...to
    end

    # The selected end from the page's end parameter: the direction of the
    # trips ending at one stopping end, or nil for every stopping end. A
    # pass-through end is rejected, since no buffer is added there.
    def self.end_go_back(param, ends:)
      return if param.blank?

      go_back = whole_number(param)
      raise Coverage::InvalidParameter, "end: #{param}" unless Ends::DIRECTIONS.include?(go_back) && ends.stopping?(go_back)

      go_back
    end

    def self.whole_minutes(param, default:, range:, name:)
      return default if param.blank?

      minutes = whole_number(param)
      raise Coverage::InvalidParameter, "#{name}: #{param}" unless range.cover?(minutes)

      minutes
    end

    # Nil unless the parameter is a string of digits.
    def self.whole_number(param) = (Integer(param, 10) if param.is_a?(String) && WHOLE_NUMBER.match?(param))
    private_class_method :whole_minutes, :whole_number

    Bound = Data.define(:lower, :upper)
    Peak = Data.define(:hour, :vehicles)
    Hour = Data.define(:hour, :lower, :upper)
    # vehicle_hours and next_minute are Bounds of numbers, exact the
    # vehicle-hours before rounding for drawing, peak a Bound of Peaks, and
    # hourly the Hours of every hour with a layover in the base.
    Point = Data.define(:hold, :vehicle_hours, :exact, :next_minute, :achieved_share, :peak, :hourly)

    attr_reader :minutes, :late, :ends, :hour_range, :end_go_back

    def initialize(route_days, minutes:, ends:, late: DEFAULT_LATE, hour_range: ALL_HOURS, end_go_back: nil)
      @route_days = route_days
      @ids = route_days.ids
      @minutes = minutes
      @late = late
      @ends = ends
      @hour_range = hour_range
      @end_go_back = end_go_back
    end

    # The minutes every turnaround has to hold: the rest plus the lateness.
    def hold = minutes + late

    # Whether the selected hours or end narrow the base.
    def filtered? = hour_range != ALL_HOURS || !end_go_back.nil?

    def n_days = @ids.size

    # The base of the estimate: the layovers at the selected stopping ends
    # that end within the selected hours.
    def n_layovers = rows_at(0).sum { it["n_layovers"] }

    # The measured layovers at every stopping end over all hours, whatever is
    # selected.
    def n_stopping_layovers
      @n_stopping_layovers ||= Layover.where(route_day_id: @ids, go_back: @ends.stopping_go_backs).count
    end

    # Each stopping end's name by direction: the last stop of that direction on
    # the latest covered day, among the stops of the page's own route, not a
    # member route's.
    def stopping_end_names
      @stopping_end_names ||= begin
        latest = @route_days.reorder(day: :desc).first
        stops = latest ? latest.stops.where(route_id: latest.route_id, go_back: @ends.stopping_go_backs).order(:seq) : []
        stops.to_h { [ it.go_back, it.stop_name ] }
      end
    end

    def n_pass_through_layovers
      @n_pass_through_layovers ||= Layover.where(route_day_id: @ids, go_back: @ends.pass_through_go_backs).count
    end

    def n_trips = trip_counts["n_trips"]

    def vehicles_per_day = trip_counts["n_vehicle_days"].fdiv(n_days).round(1)

    # One point for every whole number of minutes to hold from 0 to 40, as in
    # the requirement "Cost curve"; nil without a layover in the base.
    def curve
      return if n_layovers.zero?

      @curve ||= HOLD_RANGE.map { point_at(it) }
    end

    # The point at the minutes to hold H, whose figures are the ones reported.
    def point = curve&.at(hold)

    # Added vehicle-hours per day: the shortfall to H, and H added to every
    # layover.
    def vehicle_hours = point&.vehicle_hours

    # What holding one more minute than H adds to each bound.
    def next_minute = point&.next_minute

    # The Taipei hour with the most added minutes for each bound, the earlier
    # hour on a tie, as the average added vehicles in that hour.
    def peak = point&.peak

    # The share of layovers lasting at least the rest B. Nil without a layover
    # in the base, like everything computed from layovers.
    def achieved_share = curve&.at(minutes)&.achieved_share

    # The share that, D minutes shorter with the same vehicles, still lasts B
    # minutes: the share lasting at least H.
    def achieved_share_late = point&.achieved_share

    private

    def per_day(added_minutes) = exact_per_day(added_minutes).round(1)

    def exact_per_day(added_minutes) = added_minutes / 60 / n_days

    # The figures of one minutes to hold; the cost of one more minute takes the
    # sums of the next one before rounding, so the point at 40 needs 41.
    def point_at(held)
      rows = rows_at(held)
      lower, upper = sums(rows)
      next_lower, next_upper = sums(rows_at(held + 1))
      Point.new(
        hold: held,
        vehicle_hours: Bound.new(lower: per_day(lower), upper: per_day(upper)),
        exact: Bound.new(lower: exact_per_day(lower), upper: exact_per_day(upper)),
        next_minute: Bound.new(lower: per_day(next_lower - lower), upper: per_day(next_upper - upper)),
        achieved_share: rows.sum { it["n_held"] }.fdiv(n_layovers),
        peak: Bound.new(lower: busiest(rows, "lower"), upper: busiest(rows, "upper")),
        hourly: rows.map { Hour.new(hour: it["hour"], lower: per_day(it["lower"]), upper: per_day(it["upper"])) }
      )
    end

    # The added minutes of each bound over every hour, before rounding.
    def sums(rows) = [ rows.sum { it["lower"] }, rows.sum { it["upper"] } ]

    def busiest(rows, bound)
      row = rows.max_by { [ it[bound], -it["hour"] ] }
      Peak.new(hour: row["hour"], vehicles: per_day(row[bound]))
    end

    # The base's sums at one minutes to hold: one row per Taipei hour with a
    # layover, in hour order.
    def rows_at(held) = rows_by_hold.fetch(held, [])

    def rows_by_hold
      @rows_by_hold ||= RouteDay.connection.select_all(
        RouteDay.sanitize_sql_array([ CURVE_SQL, { ids: @ids, go_backs: base_go_backs, first_hour: hour_range.begin, last_hour: hour_range.end,
                                                   last_hold: HOLD_RANGE.max + 1 } ])
      ).to_a.group_by { it["hold"] }
    end

    # The directions whose layovers can be in the base: the selected end, or
    # every stopping end.
    def base_go_backs = end_go_back ? [ end_go_back ] : @ends.stopping_go_backs

    def trip_counts
      @trip_counts ||= RouteDay.connection.select_one(RouteDay.sanitize_sql_array([ TRIPS_SQL, { ids: @ids } ]))
    end

    # Every layover of the base against every minutes to hold from 0 to
    # :last_hold, summed by minutes to hold and the Taipei hour of the end time.
    CURVE_SQL = <<~SQL.freeze
      WITH layover_minutes AS (
          SELECT CAST(extract(hour FROM end_time AT TIME ZONE 'Asia/Taipei') AS integer) AS hour,
                 CAST(extract(epoch FROM next_start_time - end_time) / 60 AS double precision) AS minutes
          FROM layovers
          WHERE route_day_id IN (:ids) AND go_back IN (:go_backs)
      )
      SELECT hold, hour, count(*) AS n_layovers,
             count(*) FILTER (WHERE minutes >= hold) AS n_held,
             sum(greatest(hold - minutes, 0)) AS lower,
             CAST(hold * count(*) AS double precision) AS upper
      FROM layover_minutes CROSS JOIN generate_series(0, :last_hold) AS hold
      WHERE hour >= :first_hour AND hour < :last_hour
      GROUP BY hold, hour
      ORDER BY hold, hour
    SQL

    TRIPS_SQL = <<~SQL.freeze
      SELECT count(*) AS n_trips, count(DISTINCT (route_day_id, bus_id)) AS n_vehicle_days
      FROM trips
      WHERE route_day_id IN (:ids)
    SQL
    private_constant :CURVE_SQL, :TRIPS_SQL
  end
end
