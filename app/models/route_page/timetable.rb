module RoutePage
  # The data behind one day's timetable page, as in the timetable spec. The
  # browser lays the timetable out and recomputes the dispatcher's edits; the
  # server reads the derived tables and hands over the measured values: the
  # planned run time at every offered percentile for every direction and hour,
  # the measured departures per hour, the hold at each end and the stop names.
  # The hold at a stopping end is the rest; at a pass-through end it is the
  # median of the measured layovers of the covered days, rounded to a whole
  # minute, since buses only drive on from there. Nothing is stored.
  class Timetable
    DEPARTURES_RANGE = 0..30

    # The run time percentile from the page's p parameter: one of the offered
    # percentiles, 85 when left out; anything else raises like a bad day or
    # range.
    def self.percentile(param)
      return PlannedRunTimes::DEFAULT_PERCENTILE if param.blank?

      percentile = RoutePage.whole_number(param)
      raise Coverage::InvalidParameter, "p: #{param}" unless PlannedRunTimes::PERCENTILES.include?(percentile)

      percentile
    end

    attr_reader :route_days, :ends, :buffer, :percentile

    # buffer and percentile are the initial values the page starts from.
    def initialize(route_days:, ends:, buffer:, percentile:)
      @route_days = route_days
      @ends = ends
      @buffer = buffer
      @percentile = percentile
    end

    # The covered route days, oldest first, read once for the header.
    def covered = @covered ||= route_days.to_a

    def route_name = covered.last&.route_name

    # The average number of distinct vehicles per covered day, as the buffer
    # trade reports it.
    def vehicles_per_day = BufferTrade.new(route_days, minutes: buffer, ends:).vehicles_per_day

    def run_times = @run_times ||= PlannedRunTimes.new(route_days, percentile:)

    # The measured departures per direction and hour, the defaults of the
    # controls: 24 hours of both directions.
    def departures = @departures ||= MeasuredDepartures.new(route_days).counts

    # The directions without any run time; with one, no timetable can be laid out.
    def missing_run_times = @missing_run_times ||= Ends::DIRECTIONS.reject { run_times.any?(it) }

    # The minutes a vehicle waits after arriving from a trip of each direction.
    def holds = @holds ||= Ends::DIRECTIONS.to_h { [ it, ends.stopping?(it) ? buffer : pass_through_hold(it) ] }

    # The first stop of each direction on the latest covered day, among the
    # page route's own stops; a direction without stops that day has no name.
    def stop_names
      @stop_names ||= begin
        latest = route_days.reorder(day: :desc).first
        return {} unless latest

        RouteDayStop.where(route_day_id: latest.id, route_id: latest.route_id).order(:go_back, :seq).pluck(:go_back, :stop_name).uniq(&:first).to_h
      end
    end

    # The timetable checked against the measured trips, one row per offered
    # percentile, sharing the planned run times.
    def overruns = @overruns ||= TimetableOverruns.new(route_days, buffer:, run_times:).rows

    # What the browser lays the timetable out from, as the page embeds it:
    # the initial percentile and rest, the offered percentiles and ranges,
    # runTimes[direction][hour][percentile] = [whole minutes, fell back to the
    # whole day], departures[direction][hour], holds[direction] at the initial
    # rest, stoppingEnds (the directions whose hold is the rest, so the browser
    # knows which holds follow the rest control) and stopNames[direction].
    # Directions are keyed by their string, except in stoppingEnds.
    def data
      {
        "percentile" => percentile, "buffer" => buffer, "percentiles" => PlannedRunTimes::PERCENTILES,
        "bufferRange" => [ BufferTrade::MINUTES_RANGE.min, BufferTrade::MINUTES_RANGE.max ], "departuresRange" => [ DEPARTURES_RANGE.min, DEPARTURES_RANGE.max ],
        "runTimes" => by_direction { |go_back| MeasuredDepartures::HOURS.map { |hour| PlannedRunTimes::PERCENTILES.to_h { [ it.to_s, run_times.minutes_at(go_back, hour, it) ] } } },
        "departures" => by_direction { |go_back| MeasuredDepartures::HOURS.map { departures.fetch(go_back).fetch(it) } },
        "holds" => by_direction { holds.fetch(it) },
        "stoppingEnds" => ends.stopping_go_backs,
        "stopNames" => stop_names.transform_keys(&:to_s)
      }
    end

    private

    def by_direction = Ends::DIRECTIONS.to_h { |go_back| [ go_back.to_s, yield(go_back) ] }

    # The measured median layover of trips ending in the direction, rounded
    # half up; 0 without a layover.
    def pass_through_hold(go_back)
      row = layover_stats.rows.find { it.go_back == go_back }
      row&.percentiles&.fetch(LayoverStats::PERCENTILE_LEVELS.index(0.5))&.round || 0
    end

    def layover_stats = @layover_stats ||= LayoverStats.new(route_days)
  end
end
