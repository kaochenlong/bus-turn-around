module RoutePage
  # The cost of a schedule buffer of a given number of minutes at every
  # layover, as in the buffer-trade spec. Only measured layovers count; the
  # cost is a range from topping each layover up to the buffer (lower) to
  # adding the buffer to every layover (upper), in vehicle-hours per day and in
  # added vehicles in the busiest Taipei hour of the layovers' end times.
  class BufferTrade
    DEFAULT_MINUTES = 15
    MINUTES_RANGE = 0..20
    WHOLE_NUMBER = /\A\d+\z/

    # The buffer minutes from the page's buffer parameter; a value the page
    # does not accept raises like a bad day or range.
    def self.minutes(param)
      return DEFAULT_MINUTES if param.blank?

      minutes = Integer(param, 10) if param.is_a?(String) && WHOLE_NUMBER.match?(param)
      raise Coverage::InvalidParameter, "buffer: #{param}" unless MINUTES_RANGE.cover?(minutes)

      minutes
    end

    Bound = Data.define(:lower, :upper)
    Peak = Data.define(:hour, :vehicles)

    attr_reader :minutes

    def initialize(route_days, minutes:)
      @ids = route_days.ids
      @minutes = minutes
    end

    def n_days = @ids.size

    def n_layovers = hours.sum { it["n_layovers"] }

    def n_trips = trip_counts["n_trips"]

    def vehicles_per_day = trip_counts["n_vehicle_days"].fdiv(n_days).round(1)

    # Nil without a measured layover, like everything computed from layovers.
    def achieved_share
      hours.sum { it["n_achieved"] }.fdiv(n_layovers) if n_layovers.positive?
    end

    # Added vehicle-hours per day: the shortfall to the buffer, and the buffer
    # added to every layover.
    def vehicle_hours
      return if n_layovers.zero?

      Bound.new(lower: per_day(hours.sum { it["lower"] }), upper: per_day(hours.sum { it["upper"] }))
    end

    # The Taipei hour with the most added minutes for each bound, the earlier
    # hour on a tie, as the average added vehicles in that hour.
    def peak
      return if n_layovers.zero?

      Bound.new(lower: busiest("lower"), upper: busiest("upper"))
    end

    private

    def per_day(added_minutes) = (added_minutes / 60 / n_days).round(1)

    def busiest(bound)
      row = hours.max_by { [ it[bound], -it["hour"] ] }
      Peak.new(hour: row["hour"], vehicles: per_day(row[bound]))
    end

    def hours
      @hours ||= RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ HOURS_SQL, { ids: @ids, minutes: } ])).to_a
    end

    def trip_counts
      @trip_counts ||= RouteDay.connection.select_one(RouteDay.sanitize_sql_array([ TRIPS_SQL, { ids: @ids } ]))
    end

    HOURS_SQL = <<~SQL.freeze
      WITH layover_minutes AS (
          SELECT CAST(extract(hour FROM end_time AT TIME ZONE 'Asia/Taipei') AS integer) AS hour,
                 CAST(extract(epoch FROM next_start_time - end_time) / 60 AS double precision) AS minutes
          FROM layovers
          WHERE route_day_id IN (:ids)
      )
      SELECT hour, count(*) AS n_layovers,
             count(*) FILTER (WHERE minutes >= :minutes) AS n_achieved,
             sum(greatest(:minutes - minutes, 0)) AS lower,
             CAST(:minutes * count(*) AS double precision) AS upper
      FROM layover_minutes
      GROUP BY hour
      ORDER BY hour
    SQL

    TRIPS_SQL = <<~SQL.freeze
      SELECT count(*) AS n_trips, count(DISTINCT (route_day_id, bus_id)) AS n_vehicle_days
      FROM trips
      WHERE route_day_id IN (:ids)
    SQL
    private_constant :HOURS_SQL, :TRIPS_SQL
  end
end
