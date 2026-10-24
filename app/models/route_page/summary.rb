module RoutePage
  # The number of trips and of complete trips over the given route days, and
  # the trips of each route Id the page counts as one route.
  class Summary
    def initialize(route_days)
      @trips = Trip.where(route_day: route_days)
      @route_id = route_days.pick(:route_id)
    end

    def trips = @trips.count

    def complete_trips = @trips.where(completeness: "complete").count

    # [route Id, trips] for the page route and then each of its member routes
    # in the configuration's order, 0 for an Id without trips; empty without
    # route days.
    def trips_by_route
      return [] unless @route_id

      counts = @trips.group(:route_id).count
      RoutePage.member_route_ids(@route_id).map { [ it, counts.fetch(it, 0) ] }
    end
  end
end
