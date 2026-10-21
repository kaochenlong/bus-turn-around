module RoutePage
  # The number of trips and of complete trips over the given route days.
  class Summary
    def initialize(route_days)
      @trips = Trip.where(route_day: route_days)
    end

    def trips = @trips.count

    def complete_trips = @trips.where(completeness: "complete").count
  end
end
