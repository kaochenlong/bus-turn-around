module RoutePage
  # Which stored days a route page covers, from its day and range parameters.
  # Without a day it is the route's latest stored day; a range of 7d is that
  # day and the six Taipei days before it, keeping only the stored ones.
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

    def stored_days = @stored_days ||= RouteDay.where(route_id:).order(:day).pluck(:day)

    # False when the selected day itself has not been stored.
    def data? = stored_days.include?(day)

    def route_days
      first_day = day - (RANGES.fetch(range) - 1)
      RouteDay.where(route_id:, day: first_day..day).order(:day)
    end

    private

    def parse_day(text)
      raise InvalidParameter, "day: #{text}" unless ISO_DATE.match?(text)

      Date.iso8601(text)
    rescue Date::Error
      raise InvalidParameter, "day: #{text}"
    end
  end
end
