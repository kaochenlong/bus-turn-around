module RoutePage
  # The map of each end over the given route days, as in the turnaround-map
  # spec: the last stop, the first stop of the next trip, the location and the
  # toilet places as RoutePage::Facilities has them, and the standstill cells
  # of every covered day summed per cell. Only the cells whose south-west
  # corner lies within EXTENT_METERS of the last stop are listed; the others
  # are counted. A cell's level is its share of the largest listed cell, so
  # each map reads on its own. No vehicle field is read, and the vehicle counts
  # of cells are never added across days.
  class EndMap
    CELL_DEGREES = 0.0002
    EXTENT_METERS = 1000
    MIN_ZOOM = 15
    LEVELS = 4
    EARTH_RADIUS_METERS = 6_371_000

    # One end. Without end rows for its direction it has no last stop and no
    # cells; without a located day it has no location and no places.
    End = Data.define(:go_back, :nature, :last_stop, :next_first_stop, :location, :places, :cells, :cells_beyond_extent,
                      :records_shown, :records_total, :coverage_share)
    Stop = Data.define(:name, :lat, :lon)
    Location = Data.define(:lat, :lon, :source, :day)
    # A cell named by its south-west corner, with the reports summed over the
    # covered days and the number of days it appears on.
    Cell = Data.define(:lat, :lon, :records, :days, :level)

    # The page passes its RoutePage::Facilities, so the end rows and toilets
    # are read once for both blocks.
    def initialize(route_days, ends:, facilities: Facilities.new(route_days, ends:))
      @route_days = route_days
      @route_ends = ends
      @facilities = facilities
    end

    # Whether any covered day was loaded with end rows.
    def available? = end_rows.any?

    def ends = @ends ||= Ends::DIRECTIONS.map { build_end(it) }

    private

    def build_end(go_back)
      latest = end_rows.find { it.go_back == go_back }
      last_stop = latest && Stop.new(name: latest.end_stop_name, lat: latest.end_latitude, lon: latest.end_longitude)
      kept, beyond = cells_of(go_back).partition { |lat, lon, _records, _days| within_extent?(last_stop, lat, lon) }
      cells = leveled(kept)
      shown = cells.sum(&:records)
      total = end_rows.select { it.go_back == go_back }.sum(&:n_standstill_records)
      facility = @facilities.ends.find { it.go_back == go_back }
      End.new(go_back:, nature: @route_ends.nature(go_back), last_stop:, next_first_stop: next_first_stop(go_back),
              location: location(facility), places: facility.places, cells:, cells_beyond_extent: beyond.size,
              records_shown: shown, records_total: total, coverage_share: total.zero? ? nil : shown.fdiv(total))
    end

    # Every end row of the covered days with the day it belongs to, newest first.
    def end_rows
      @end_rows ||= RouteDayEnd.joins(:route_day).where(route_day_id: @route_days.select(:id))
                               .select("route_day_ends.*", "route_days.day AS day").sort_by(&:day).reverse
    end

    # [latitude, longitude, reports, days] of each cell of one end, summed over
    # the covered days, by latitude and then longitude.
    def cells_of(go_back) = summed_cells.filter_map { |direction, *cell| cell if direction == go_back }

    def summed_cells
      @summed_cells ||= RouteDayEndCell.joins(:route_day_end)
                                       .where(route_day_ends: { route_day_id: @route_days.select(:id) })
                                       .group("route_day_ends.go_back", :cell_latitude, :cell_longitude)
                                       .order(:cell_latitude, :cell_longitude)
                                       .pluck("route_day_ends.go_back", :cell_latitude, :cell_longitude,
                                              Arel.sql("sum(route_day_end_cells.n_records)"),
                                              Arel.sql("count(DISTINCT route_day_ends.route_day_id)"))
    end

    # A share of at most 1/4 of the largest cell is level 1, at most 2/4 level
    # 2, and so on; the arithmetic is exact, so a share on a boundary keeps its
    # level.
    def leveled(cells)
      largest = cells.map { it[2] }.max
      cells.map { |lat, lon, records, days| Cell.new(lat:, lon:, records:, days:, level: Rational(records * LEVELS, largest).ceil) }
    end

    def within_extent?(last_stop, lat, lon)
      return false unless last_stop&.lat && last_stop.lon

      meters_between(last_stop.lat, last_stop.lon, lat, lon) <= EXTENT_METERS
    end

    # The first stop of the other direction on the latest covered day.
    def next_first_stop(go_back)
      stop = latest_day_stops.select { it.go_back == 1 - go_back }.min_by(&:seq)
      stop && Stop.new(name: stop.stop_name, lat: stop.latitude, lon: stop.longitude)
    end

    # reorder, not order: the page passes the days already ordered oldest first.
    def latest_day_stops = @latest_day_stops ||= RouteDayStop.where(route_day_id: @route_days.reorder(day: :desc).limit(1).select(:id)).to_a

    def location(facility)
      return unless facility.located_day

      Location.new(lat: facility.latitude, lon: facility.longitude, source: facility.location_source, day: facility.located_day)
    end

    # Haversine distance on a sphere of EARTH_RADIUS_METERS, as in analysis/.
    def meters_between(lat1, lon1, lat2, lon2)
      radians = Math::PI / 180
      a = (Math.sin((lat2 - lat1) * radians / 2)**2) +
          (Math.cos(lat1 * radians) * Math.cos(lat2 * radians) * (Math.sin((lon2 - lon1) * radians / 2)**2))
      2 * EARTH_RADIUS_METERS * Math.asin(Math.sqrt(a))
    end
  end
end
