module RoutePage
  # The departures per direction and Taipei hour measured over the given route
  # days, the default of the timetable: the stored trips starting in that
  # hour, of every completeness, divided by the number of covered days and
  # rounded half up. The timetable starts from how the route runs today, not from
  # the published headway.
  class MeasuredDepartures
    HOURS = (0...24).to_a.freeze

    def initialize(route_days)
      @ids = route_days.ids
    end

    # { go_back => { hour => Integer } }, with a key for every hour of both
    # directions; an hour without a trip is 0.
    def counts
      @counts ||= Ends::DIRECTIONS.to_h do |go_back|
        [ go_back, HOURS.to_h { |hour| [ hour, average(trip_counts.fetch([ go_back, hour ], 0)) ] } ]
      end
    end

    private

    # Rounded half up by Rational, so 4.5 trips a day is 5; without a covered
    # day everything is 0.
    def average(n_trips) = @ids.empty? ? 0 : Rational(n_trips, @ids.size).round

    def trip_counts
      @trip_counts ||= Trip.where(route_day_id: @ids).group(:go_back, Arel.sql(HOUR_SQL)).count
    end

    HOUR_SQL = "CAST(extract(hour FROM start_time AT TIME ZONE 'Asia/Taipei') AS integer)".freeze
    private_constant :HOUR_SQL
  end
end
