module RoutePage
  # Round trips and cycles over the given route days, as in the
  # round-trip-cycle spec. A round trip leaves the stopping end in the lead
  # direction and comes back in the back direction: from the lead trip's start
  # to the end of the back trip that follows it on the same vehicle. A cycle
  # is the time between two returns of a vehicle to the stopping end: from the
  # end of a back trip to the end of the next one, with one lead trip between
  # them. Every link between two trips is a stored layover, so the trips are
  # adjacent and the vehicle ran no other route in between. Grouped by the
  # Taipei hour of the lead trip's start, with an all-day row that pools every
  # hour, and percentiles interpolated linearly and kept to one decimal: p50
  # and p85 of round trips, p10 and p50 of cycles. A measure with fewer than
  # RunTimes::SMALL_SAMPLE values in a row is a small sample, as in run times.
  class Cycles
    PERCENTILE_LEVELS = { round_trip: [ 0.5, 0.85 ], cycle: [ 0.1, 0.5 ] }.freeze

    Row = Data.define(:hour, :n_round_trips, :round_trip_percentiles, :n_cycles, :cycle_percentiles) do
      def round_trip_small_sample? = n_round_trips < RunTimes::SMALL_SAMPLE

      def cycle_small_sample? = n_cycles < RunTimes::SMALL_SAMPLE
    end

    def initialize(route_days, ends:)
      @ids = route_days.ids
      # reorder, not order: the page passes the days already ordered oldest first.
      @latest_id = route_days.reorder(day: :desc).pick(:id)
      @ends = ends
    end

    # The direction whose trips leave the stopping end: direction 0, unless
    # its trips end at a stopping end and direction 1's at a pass-through end.
    def lead_go_back = @ends.nature(0) == :stop && @ends.nature(1) == :pass_through ? 1 : 0

    def back_go_back = 1 - lead_go_back

    # Where a round trip leaves: the first stop of the lead direction on the
    # latest of the days; nil when that day has no stops.
    def first_stop_name = stop_names.first

    # Where a round trip and a cycle return: the last stop of the back
    # direction on the latest of the days; nil when that day has no stops.
    def last_stop_name = stop_names.last

    # Whether the lead trips end at a stopping end, so that a round trip
    # includes a rest at the other end rather than a pass-through.
    def far_end_stopping? = @ends.stopping?(lead_go_back)

    # Every Taipei hour with a round trip or a cycle, in hour order.
    def rows = hours_and_total.first

    # Every hour pooled, with a nil hour.
    def total = hours_and_total.last

    def any_round_trips? = total.n_round_trips.positive?

    private

    def stop_names
      @stop_names ||= begin
        stops = RouteDayStop.where(route_day_id: @latest_id)
        [ stops.where(go_back: lead_go_back).order(:seq).pick(:stop_name), stops.where(go_back: back_go_back).order(seq: :desc).pick(:stop_name) ]
      end
    end

    # Read once: the hourly rows and the all-day row come from one query.
    def hours_and_total
      @hours_and_total ||= begin
        all = RouteDay.connection.select_all(RouteDay.sanitize_sql_array([ sql, { ids: @ids, lead: lead_go_back, back: back_go_back } ])).map do |row|
          Row.new(hour: row["hour"], n_round_trips: row["n_round_trips"], round_trip_percentiles: percentiles(row, :round_trip),
                  n_cycles: row["n_cycles"], cycle_percentiles: percentiles(row, :cycle))
        end
        totals, hours = all.partition { it.hour.nil? }
        [ hours, totals.sole ]
      end
    end

    # Nil for every level when the row has no value of that kind.
    def percentiles(row, kind) = PERCENTILE_LEVELS.fetch(kind).each_index.map { row["#{kind}_p#{it}"]&.to_f }

    # Round trips: a complete lead trip that leaves with an observed departure,
    # the stored layover after it and the complete back trip that ends with an
    # observed arrival. Cycles: an earlier back trip that ends with an observed
    # arrival, the stored layover after it, a lead trip of any completeness,
    # the stored layover after that and a later back trip that is complete and
    # ends with an observed arrival.
    def sql
      percentiles = PERCENTILE_LEVELS.flat_map do |kind, levels|
        levels.each_with_index.map do |level, index|
          "round(CAST(percentile_cont(#{level}) WITHIN GROUP (ORDER BY minutes) FILTER (WHERE kind = '#{kind}') AS numeric), 1) AS #{kind}_p#{index}"
        end
      end
      <<~SQL
        WITH round_trips AS (
            SELECT lead_trip.start_time AS lead_start_time,
                   CAST(extract(epoch FROM back_trip.end_time - lead_trip.start_time) / 60 AS double precision) AS minutes
            FROM trips lead_trip
            JOIN layovers lead_layover
              ON lead_layover.route_day_id = lead_trip.route_day_id AND lead_layover.bus_id = lead_trip.bus_id
             AND lead_layover.go_back = lead_trip.go_back AND lead_layover.end_time = lead_trip.end_time
            JOIN trips back_trip
              ON back_trip.route_day_id = lead_layover.route_day_id AND back_trip.bus_id = lead_layover.bus_id
             AND back_trip.start_time = lead_layover.next_start_time
            WHERE lead_trip.route_day_id IN (:ids) AND lead_trip.go_back = :lead
              AND lead_trip.completeness = 'complete' AND NOT lead_trip.start_from_arrival
              AND back_trip.go_back = :back AND back_trip.completeness = 'complete' AND NOT back_trip.end_from_departure
        ),
        cycles AS (
            SELECT lead_trip.start_time AS lead_start_time,
                   CAST(extract(epoch FROM later_back.end_time - earlier_back.end_time) / 60 AS double precision) AS minutes
            FROM layovers back_layover
            JOIN trips earlier_back
              ON earlier_back.route_day_id = back_layover.route_day_id AND earlier_back.bus_id = back_layover.bus_id
             AND earlier_back.go_back = back_layover.go_back AND earlier_back.end_time = back_layover.end_time
            JOIN trips lead_trip
              ON lead_trip.route_day_id = back_layover.route_day_id AND lead_trip.bus_id = back_layover.bus_id
             AND lead_trip.start_time = back_layover.next_start_time
            JOIN layovers lead_layover
              ON lead_layover.route_day_id = lead_trip.route_day_id AND lead_layover.bus_id = lead_trip.bus_id
             AND lead_layover.go_back = lead_trip.go_back AND lead_layover.end_time = lead_trip.end_time
            JOIN trips later_back
              ON later_back.route_day_id = lead_layover.route_day_id AND later_back.bus_id = lead_layover.bus_id
             AND later_back.start_time = lead_layover.next_start_time
            WHERE back_layover.route_day_id IN (:ids) AND back_layover.go_back = :back AND NOT earlier_back.end_from_departure
              AND lead_trip.go_back = :lead
              AND later_back.go_back = :back AND later_back.completeness = 'complete' AND NOT later_back.end_from_departure
        ),
        measures AS (
            SELECT 'round_trip' AS kind, lead_start_time, minutes FROM round_trips
            UNION ALL
            SELECT 'cycle', lead_start_time, minutes FROM cycles
        ),
        hourly AS (
            SELECT kind, CAST(extract(hour FROM lead_start_time AT TIME ZONE 'Asia/Taipei') AS integer) AS hour, minutes
            FROM measures
        )
        SELECT hour,
               count(*) FILTER (WHERE kind = 'round_trip') AS n_round_trips,
               count(*) FILTER (WHERE kind = 'cycle') AS n_cycles,
               #{percentiles.join(', ')}
        FROM hourly
        GROUP BY GROUPING SETS ((hour), ())
        ORDER BY hour
      SQL
    end
  end
end
