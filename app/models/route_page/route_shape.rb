module RoutePage
  # The route map of the given route days, as in the route-shape spec: the
  # route shapes of the latest day that has any, whatever order the days come
  # in, and the first and last stop of each drawn direction on that same day,
  # so the lines and their stops always belong together. It reads at most
  # three queries, each once.
  class RouteShape
    Line = Data.define(:go_back, :points)
    EndStops = Data.define(:go_back, :first, :last)
    Stop = Data.define(:name, :lat, :lon)

    def initialize(route_days)
      # reorder, not order: the page passes the days already ordered oldest first.
      @route_day_id = route_days.where(id: RouteDayShape.select(:route_day_id)).reorder(day: :desc).pick(:id)
    end

    def available? = !@route_day_id.nil?

    # Each stored direction of the day drawn, in direction order.
    def lines = @lines ||= shapes.map { |go_back, points, _updated_at| Line.new(go_back:, points:) }

    # The latest update among the drawn directions, as a Taipei day.
    def updated_on = shapes.map(&:last).max&.to_date

    # The first and the last stop of each drawn direction, by sequence number.
    def end_stops
      @end_stops ||= RouteDayStop.where(route_day_id: @route_day_id, go_back: lines.map(&:go_back)).order(:go_back, :seq)
                                 .pluck(:go_back, :stop_name, :latitude, :longitude).group_by(&:first)
                                 .map { |go_back, stops| EndStops.new(go_back:, first: stop(stops.first), last: stop(stops.last)) }
    end

    private

    # [direction, points, update time] of each direction of the day drawn.
    def shapes
      @shapes ||= available? ? RouteDayShape.where(route_day_id: @route_day_id).order(:go_back).pluck(:go_back, :points, :shape_updated_at) : []
    end

    def stop((_go_back, name, lat, lon)) = Stop.new(name:, lat:, lon:)
  end
end
