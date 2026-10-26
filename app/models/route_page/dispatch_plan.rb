module RoutePage
  # Today's plan on the day dispatch page, as in the day-dispatch spec: which
  # day type it is laid out for and which stored days it covers. The office
  # calendar that says whether today is a holiday is not on the web server,
  # and today's own data is only loaded tomorrow, so the day type follows the
  # day of the week unless the dispatcher selects one.
  class DispatchPlan
    DAY_TYPES = %w[weekday holiday].freeze

    # The day type from the page's type parameter: weekday or holiday as
    # given; when left out, weekday from Monday to Friday of today and
    # holiday on Saturday and Sunday; anything else raises like a bad day or
    # range.
    def self.day_type(type, today)
      return today.saturday? || today.sunday? ? "holiday" : "weekday" if type.blank?
      raise Coverage::InvalidParameter, "type: #{type}" unless DAY_TYPES.include?(type)

      type
    end

    attr_reader :route_id, :day_type

    # today: the current Taipei date.
    def initialize(route_id:, type:, today:)
      @route_id = route_id
      @day_type = self.class.day_type(type, today)
    end

    # The latest stored day of the day type with the stored days of that type
    # among the seven Taipei days up to it, as the timetable page covers 7d;
    # nil when the route has no stored day of that type.
    def coverage
      return @coverage if defined?(@coverage)

      latest = RouteDay.where(route_id:, day_type:).maximum(:day)
      @coverage = latest && Coverage.new(route_id:, day: latest.iso8601, range: "7d")
    end
  end
end
