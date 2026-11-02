module RoutePage
  # The published schedule of a page route over any given route days, against
  # what the stored trips measured, as in the published-schedule spec. Each day
  # reads one date value of the rows stored with it, and the rows of a route Id's
  # sub-routes are merged, repeats removed. A route Id's rows only count its own
  # trips and vehicles. It reports numbers only: public data has no approved trips
  # or vehicle numbers, so nothing here says whether a departure was missed or why
  # the two differ, and no plate leaves this object.
  class ScheduleComparison
    # GetSemiTimeTable.gz and GetTimeTable.gz number the week from Sunday, as 1.
    SUNDAY = 1
    MONDAY = 2
    SATURDAY = 7
    SLICE_MINUTES = 30
    MINUTES_PER_DAY = 1440
    HOURS = (0...24).to_a.freeze

    # Adjacent days that read the same periods and scheduled departures, with
    # figures from those days only. others is nil when nothing falls outside the
    # periods.
    Version = Data.define(:days, :periods, :others)
    # per_hour_low and per_hour_high are the published departures per hour, 60
    # divided by the high and by the low headway. departures_per_hour is
    # { go_back => Float }. needed_low and needed_high are nil without a cycle.
    Period = Data.define(:start_minute, :end_minute, :low_minutes, :high_minutes, :per_hour_low, :per_hour_high,
                         :departures_per_hour, :on_road, :needed_low, :needed_high)
    # What falls outside every period: the scheduled departures as minutes of the
    # day, the trips per day as { go_back => Float }, and the vehicles on the road
    # over the slices of that time with a vehicle on a trip. They are not matched
    # one by one.
    Others = Data.define(:departures, :trips_per_day, :on_road)
    # A member route's figures over its own version of the days, so normally one
    # row per member route.
    MemberRow = Data.define(:route_id, :route_name, :days, :periods, :others)
    # departures is { go_back => Float }, per day.
    Hour = Data.define(:hour, :departures, :on_road)
    StoredDay = Data.define(:id, :day, :date_value, :published_schedule_day)
    TripSpan = Data.define(:bus_id, :go_back, :start_minute, :end_minute)
    private_constant :StoredDay, :TripSpan

    # The date value a route day reads: a weekday on Monday to Friday its own day
    # of the week, a holiday on Saturday the Saturday table, any other holiday
    # the Sunday table, and a weekday on a weekend, a make-up workday, the Monday
    # table. The tables of a holiday on a weekday and of a make-up workday are an
    # assumption, as the published-schedule spec's date value table states.
    def self.date_value(day, day_type)
      case day_type
      when "weekday" then day.saturday? || day.sunday? ? MONDAY : day.wday + SUNDAY
      when "holiday" then day.saturday? ? SATURDAY : SUNDAY
      else raise ArgumentError, "不認得的日型別：#{day_type}"
      end
    end

    def initialize(route_days, route_id:, cycles:)
      @route_id = route_id
      @cycles = cycles
      # reorder, not order: a caller may pass the days already ordered.
      stored = route_days.reorder(:day).pluck(:id, :day, :day_type, :published_schedule_day, :member_names)
      @days = stored.map do |id, day, day_type, published_schedule_day, _|
        StoredDay.new(id:, day:, date_value: self.class.date_value(day, day_type), published_schedule_day:)
      end
      # The latest day's name wins.
      @member_names = stored.map(&:last).reduce({}, :merge)
    end

    def versions
      @versions ||= versions_of(@route_id)
    end

    def member_rows
      @member_rows ||= member_route_ids.flat_map do |route_id|
        versions_of(route_id, published_only: true).map do |version|
          MemberRow.new(route_id:, route_name: @member_names[route_id.to_s], days: version.days, periods: version.periods, others: version.others)
        end
      end
    end

    # The Taipei hours of the day in which a trip of the page route runs.
    def hours
      @hours ||= begin
        trips_by_day = trips_on(@days, @route_id)
        figures = trips_by_day.flatten.empty? ? [] : HOURS.map { hour_figures(it, trips_by_day) }
        figures.select { it.on_road.positive? || it.departures.values.any?(&:positive?) }
      end
    end

    # Days stored before these tables existed have no rows until they are loaded
    # again, which the rows cannot tell from a route that publishes nothing.
    def needs_reload? = @days.any? { it.published_schedule_day.nil? }

    private

    def versions_of(route_id, published_only: false)
      groups = @days.slice_when { |earlier, later| table(earlier, route_id) != table(later, route_id) }
      groups = groups.reject { table(it.first, route_id).all?(&:empty?) } if published_only
      groups.map { version(route_id, it) }
    end

    def version(route_id, days)
      trips_by_day = trips_on(days, route_id)
      rows, departures = table(days.first, route_id)
      Version.new(days: days.map(&:day), periods: rows.map { period(it, trips_by_day) }, others: others(rows, departures, trips_by_day))
    end

    # What a day reads for a route Id: its periods and its scheduled departures,
    # without repeats, in time order. Two days with the same table belong together
    # whichever date values they read.
    def table(day, route_id)
      key = [ day.id, route_id, day.date_value ]
      [ headway_rows.fetch(key, []).sort, departure_minutes.fetch(key, []).sort ]
    end

    # One list of a route Id's trips per day, empty for a day without any, so the
    # days without a trip still count in every mean.
    def trips_on(days, route_id) = days.map { trip_spans.fetch([ it.id, route_id ], []) }

    def period(row, trips_by_day)
      start_minute, end_minute, low_minutes, high_minutes = row
      Period.new(start_minute:, end_minute:, low_minutes:, high_minutes:, per_hour_low: 60.0 / high_minutes, per_hour_high: 60.0 / low_minutes,
                 departures_per_hour: departures_per_hour(trips_by_day, start_minute, end_minute),
                 on_road: mean(vehicle_counts(trips_by_day, slices(start_minute, end_minute))),
                 needed_low: needed(high_minutes), needed_high: needed(low_minutes))
    end

    def others(rows, departures, trips_by_day)
      outside_departures = departures.reject { inside?(rows, it) }
      outside_trips = trips_by_day.flatten.reject { inside?(rows, it.start_minute) }
      return if outside_departures.empty? && outside_trips.empty?

      counts = vehicle_counts(trips_by_day, spans_outside(rows).flat_map { |from, to| slices(from, to) })
      Others.new(departures: outside_departures, trips_per_day: per_direction(outside_trips, trips_by_day.size), on_road: mean(counts.select(&:positive?)))
    end

    def hour_figures(hour, trips_by_day)
      start_minute = hour * 60
      end_minute = start_minute + 60
      Hour.new(hour:, departures: departures_per_hour(trips_by_day, start_minute, end_minute),
               on_road: mean(vehicle_counts(trips_by_day, slices(start_minute, end_minute))))
    end

    # The trips starting in the time span, per direction, over the days and the
    # span's hours, unrounded.
    def departures_per_hour(trips_by_day, start_minute, end_minute)
      starting = trips_by_day.flatten.select { it.start_minute >= start_minute && it.start_minute < end_minute }
      per_direction(starting, trips_by_day.size).transform_values { it / ((end_minute - start_minute) / 60.0) }
    end

    def per_direction(trips, n_days) = Ends::DIRECTIONS.to_h { |go_back| [ go_back, trips.count { it.go_back == go_back }.fdiv(n_days) ] }

    # A period starts at its start and stops before its end: a departure at 21:00
    # is outside a period ending at 21:00.
    def inside?(rows, minute) = rows.any? { |start_minute, end_minute, *| minute >= start_minute && minute < end_minute }

    # The parts of the day outside every period, as [from, to] in time order.
    def spans_outside(rows)
      reached = 0
      spans = rows.filter_map do |start_minute, end_minute, *|
        span = [ reached, start_minute ] if start_minute > reached
        reached = [ reached, end_minute ].max
        span
      end
      reached < MINUTES_PER_DAY ? spans << [ reached, MINUTES_PER_DAY ] : spans
    end

    # The vehicles on a trip, for every day and slice. A vehicle between two trips
    # is not on the road.
    def vehicle_counts(trips_by_day, slices)
      trips_by_day.flat_map { |trips| slices.map { |from, to| vehicles_between(trips, from, to) } }
    end

    # A trip ending exactly where the slice starts is not on the road in it.
    def vehicles_between(trips, from, to) = trips.select { it.start_minute < to && it.end_minute > from }.map(&:bus_id).uniq.size

    # Slices from the start of the time span; the last may be shorter.
    def slices(start_minute, end_minute)
      start_minute.step(end_minute - 1, SLICE_MINUTES).map { [ it, [ it + SLICE_MINUTES, end_minute ].min ] }
    end

    def mean(counts) = counts.empty? ? 0.0 : counts.sum.fdiv(counts.size)

    # One vehicle starts one departure per cycle, so a headway takes the cycle
    # divided by the headway; the cycle includes the rests, so this is at today's
    # rhythm, not a minimum.
    def needed(headway_minutes) = cycle_p50 && (cycle_p50 / headway_minutes).round

    # RoutePage::Cycles reports p10 and p50 of cycles.
    def cycle_p50 = @cycles.total.cycle_percentiles.last

    # The member routes with a published row on any of the days, by route Id.
    def member_route_ids = (headway_rows.keys + departure_minutes.keys).map(&:second).uniq.without(@route_id).sort

    # [start, end, low, high] keyed by route day, route Id and date value. The
    # sub-route is not read, so the same period on two sub-routes is one row.
    def headway_rows
      @headway_rows ||= RouteDayPublishedHeadway.where(route_day_id: @days.map(&:id)).distinct
                                                .pluck(:route_day_id, :route_id, :date_value, :start_minute, :end_minute, :low_minutes, :high_minutes)
                                                .group_by { it.first(3) }.transform_values { |rows| rows.map { it.drop(3) } }
    end

    # The minutes of the scheduled departures, keyed the same way.
    def departure_minutes
      @departure_minutes ||= RouteDayPublishedDeparture.where(route_day_id: @days.map(&:id)).distinct
                                                       .pluck(:route_day_id, :route_id, :date_value, :minute)
                                                       .group_by { it.first(3) }.transform_values { |rows| rows.map(&:last) }
    end

    # The stored trips keyed by route day and route Id, their times as minutes
    # from the Taipei midnight of the day, so a trip past midnight ends after 1440.
    def trip_spans
      @trip_spans ||= RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ TRIPS_SQL, { ids: @days.map(&:id) } ])).to_a
                              .group_by { it.values_at("route_day_id", "route_id") }
                              .transform_values do |rows|
        rows.map { TripSpan.new(bus_id: it["bus_id"], go_back: it["go_back"], start_minute: it["start_minute"], end_minute: it["end_minute"]) }
      end
    end

    TRIPS_SQL = <<~SQL.freeze
      SELECT t.route_day_id, t.route_id, t.bus_id, t.go_back,
             CAST(extract(epoch FROM t.start_time - (CAST(d.day AS timestamp) AT TIME ZONE 'Asia/Taipei')) / 60 AS double precision) AS start_minute,
             CAST(extract(epoch FROM t.end_time - (CAST(d.day AS timestamp) AT TIME ZONE 'Asia/Taipei')) / 60 AS double precision) AS end_minute
      FROM trips t
      JOIN route_days d ON d.id = t.route_day_id
      WHERE t.route_day_id IN (:ids)
    SQL
    private_constant :TRIPS_SQL
  end
end
