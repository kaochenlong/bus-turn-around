module RoutePage
  # The slowest stretches between two stops in the morning and evening peaks, as
  # RoutePage::StopSpeeds reports them. A short stretch or a small sample says more
  # about the few trips than about the road, so neither is listed.
  class SlowLegs
    BANDS = %w[morning_peak evening_peak].freeze
    MIN_METERS = 200
    LIMIT = 4

    Row = Data.define(:go_back, :from_name, :to_name, :band, :meters, :n_trips, :kmh)

    def initialize(stop_speeds)
      @stop_speeds = stop_speeds
    end

    # The slowest first; the direction and the stretch's place break a tie, so the
    # order does not depend on the rows' order.
    def rows
      @rows ||= @stop_speeds.directions.flat_map { direction_rows(it) }.sort_by { [ it.kmh, it.go_back, it.from_name, it.band ] }.first(LIMIT)
    end

    private

    def direction_rows(direction)
      direction.legs.select { it.meters >= MIN_METERS }.flat_map do |leg|
        BANDS.filter_map do |band|
          cell = leg.cells[band]
          next if cell.nil? || cell.kmh.nil? || cell.small_sample

          Row.new(go_back: direction.go_back, from_name: leg.from_name, to_name: leg.to_name, band:, meters: leg.meters, n_trips: cell.n_trips, kmh: cell.kmh)
        end
      end
    end
  end
end
