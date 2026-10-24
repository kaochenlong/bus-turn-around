module RoutePage
  # The depots the vehicles of the covered days belong to, as in the
  # turnaround-facilities spec: the depot rows of one day, the most vehicles
  # first, each matched with the newest term of the depot inspection scores as
  # scored, not in the appendix or not checked yet. The rows are those of the
  # latest covered day that has any, and that day is named: a day loaded
  # before route_day_depots existed has none. When no covered day has any, the
  # days have to be loaded again. Nothing here judges a score.
  class Depots
    # One depot of the day. The names are empty when the day's static
    # snapshot had no GetProvider.gz; inspection is nil unless status is :scored.
    Row = Data.define(:provider_name, :station_name, :station_id, :n_buses, :n_trips, :status, :inspection) do
      def named? = provider_name.present? && station_name.present?
    end

    attr_reader :term

    def initialize(route_days, term: DepotInspections.current)
      @route_days = route_days
      @term = term
    end

    def needs_reload? = latest_day.nil?

    # The day the rows are of, or nil.
    def day = latest_day&.day

    def rows = @rows ||= latest_day ? build_rows : []

    private

    # Reordered, because the covered days arrive ordered by day and a second
    # order would only be appended to that one.
    def latest_day
      return @latest_day if defined?(@latest_day)

      @latest_day = @route_days.where(id: RouteDayDepot.select(:route_day_id)).reorder(day: :desc).first
    end

    def build_rows
      RouteDayDepot.where(route_day_id: latest_day.id).order(n_buses: :desc, station_id: :asc).map do |depot|
        status, inspection = @term.status_of(depot.provider_name, depot.station_name)
        Row.new(provider_name: depot.provider_name, station_name: depot.station_name, station_id: depot.station_id,
                n_buses: depot.n_buses, n_trips: depot.n_trips, status:, inspection:)
      end
    end
  end
end
