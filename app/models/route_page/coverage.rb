module RoutePage
  # Which stored days a route page covers, from its day and range parameters.
  # Without a day it is the route's latest stored day; a range of 7d is that
  # day and the six Taipei days before it, keeping only the stored ones of the
  # selected day's day type, so weekdays and holidays are never pooled.
  class Coverage
    RANGES = { "day" => 1, "7d" => 7 }.freeze
    ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/

    # A day or range parameter the page does not accept.
    class InvalidParameter < StandardError; end

    attr_reader :route_id, :range, :day

    def initialize(route_id:, day: nil, range: nil)
      @route_id = route_id
      @range = range.presence || "day"
      raise InvalidParameter, "range: #{range}" unless RANGES.key?(@range)

      @day = day.present? ? parse_day(day) : stored_days.last
    end

    def stored_days = @stored_days ||= stored.map(&:first)

    # False when the selected day itself has not been stored.
    def data? = stored_days.include?(day)

    # The selected day's day type, or nil when that day has not been stored.
    def day_type = day_type_on(day)

    # A stored day's day type, or nil when that day has not been stored.
    def day_type_on(a_day) = stored.find { |stored_day, _| stored_day == a_day }&.last

    # The latest stored day on or before the selected day whose day type
    # differs from the selected day's, or nil when there is none.
    def other_type_day
      return unless day_type

      stored.reverse_each.find { |stored_day, type| stored_day <= day && type != day_type }&.first
    end

    def route_days
      first_day = day - (RANGES.fetch(range) - 1)
      RouteDay.where(route_id:, day: first_day..day, day_type:).order(:day)
    end

    private

    # Every stored day of the route with its day type, oldest first, read once.
    def stored = @stored ||= RouteDay.where(route_id:).order(:day).pluck(:day, :day_type)

    def parse_day(text)
      raise InvalidParameter, "day: #{text}" unless ISO_DATE.match?(text)

      Date.iso8601(text)
    rescue Date::Error
      raise InvalidParameter, "day: #{text}"
    end
  end
end
