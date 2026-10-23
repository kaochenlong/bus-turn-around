module RoutePage
  # The turnaround facilities over the given route days, as in the
  # turnaround-facilities spec. A location cannot be pooled over days, so each
  # end shows the latest covered day that carries one and names that day. The
  # toilets stored for it are grouped into places by address, a place being
  # where its nearest toilet is, and counted within each threshold. Nothing
  # here judges whether the toilets are enough. The standstill cells are left
  # to the map.
  class Facilities
    THRESHOLDS = [ 300, 500 ].freeze
    MAIN_THRESHOLD = 300
    # The radius of a located layover, located_radius_meters in
    # analysis/params.sql; the page names it next to that count.
    LOCATED_RADIUS_METERS = 150

    # One end. Its toilet snapshot day is the one its located day was loaded
    # with, the source of its places. Without a located day, the snapshot day,
    # location, check numbers, counts, nearest place and places are empty, and
    # the numbers of layovers and standstill reports are those of the latest
    # covered day.
    End = Data.define(:go_back, :nature, :end_stop_name, :located_day, :public_toilets_day, :n_days_without_location,
                      :location_source, :latitude, :longitude, :n_layovers, :n_located_layovers, :n_standstill_records,
                      :end_stop_meters, :counts, :nearest, :places)
    # The stored toilets at one address, named after the nearest of them, with
    # its category, distance and coordinates and the number of toilets there.
    Place = Data.define(:name, :category, :address, :meters, :n_toilets, :latitude, :longitude)

    def initialize(route_days, ends:)
      @route_days = route_days
      @route_ends = ends
    end

    # No covered day was loaded with end rows, so the days have to be loaded again.
    def needs_reload? = end_rows.empty?

    def ends = @ends ||= Ends::DIRECTIONS.map { build_end(it) }

    private

    # Every end row of the covered days with its day and that day's toilet
    # snapshot day, newest first.
    def end_rows
      @end_rows ||= RouteDayEnd.joins(:route_day).where(route_day_id: @route_days.select(:id))
                               .select("route_day_ends.*", "route_days.day AS day", "route_days.public_toilets_day AS public_toilets_day")
                               .sort_by(&:day).reverse
    end

    def build_end(go_back)
      rows = end_rows.select { it.go_back == go_back }
      located = rows.find(&:latitude)
      row = located || rows.first
      places = located ? places_of(located) : []
      End.new(go_back:, nature: @route_ends.nature(go_back), end_stop_name: row&.end_stop_name, located_day: located&.day,
              public_toilets_day: located&.public_toilets_day,
              n_days_without_location: n_covered_days - rows.count(&:latitude), location_source: located&.location_source,
              latitude: located&.latitude, longitude: located&.longitude, n_layovers: row&.n_layovers,
              n_located_layovers: located&.n_located_layovers, n_standstill_records: row&.n_standstill_records,
              end_stop_meters: located&.end_stop_meters, counts: located && counts(places), nearest: places.first, places:)
    end

    def n_covered_days = @n_covered_days ||= @route_days.size

    def counts(places) = THRESHOLDS.to_h { |meters| [ meters, places.count { it.meters <= meters } ] }

    # A toilet without an address is a place of its own, so it is never merged
    # into another place.
    def places_of(row)
      toilets_by_end.fetch(row.id, [])
                    .group_by { it.address.present? ? [ :address, it.address ] : [ :toilet, it.id ] }
                    .values.map { place(it) }
                    .select { it.meters <= THRESHOLDS.max }
                    .sort_by { [ it.meters, it.name ] }
    end

    def place(toilets)
      nearest = toilets.min_by { [ it.meters, it.name ] }
      Place.new(name: nearest.name, category: nearest.category, address: nearest.address, meters: nearest.meters,
                n_toilets: toilets.size, latitude: nearest.latitude, longitude: nearest.longitude)
    end

    # The toilets of the located rows, read in one query.
    def toilets_by_end
      @toilets_by_end ||= RouteDayEndToilet.where(route_day_end_id: end_rows.select(&:latitude).map(&:id)).group_by(&:route_day_end_id)
    end
  end
end
