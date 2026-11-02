module RoutePage
  # What changed in the static snapshots over any given route days, as in the
  # published-schedule spec: each day against the one before it in date order. It
  # compares what the derived tables stored, so it only sees the days that were
  # loaded, and a change during a skipped day shows on the next loaded day. The
  # first day has nothing before it and never counts.
  class SnapshotChanges
    # kinds lists what differs from the day before, in this order:
    # :published_schedule, :stops and :shape.
    Change = Data.define(:day, :kinds)
    StoredDay = Data.define(:id, :day, :published_schedule_day)
    private_constant :StoredDay

    def initialize(route_days)
      # reorder, not order: a caller may pass the days in any order.
      @days = route_days.reorder(:day).pluck(:id, :day, :published_schedule_day).map do |id, day, published_schedule_day|
        StoredDay.new(id:, day:, published_schedule_day:)
      end
    end

    def n_days = @days.size

    def changes
      @changes ||= @days.each_cons(2).filter_map do |previous, day|
        kinds = []
        kinds << :published_schedule if published_change_ids.include?(day.id)
        kinds << :stops if stop_rows[previous.id] != stop_rows[day.id]
        kinds << :shape if shape_rows[previous.id] != shape_rows[day.id]
        Change.new(day: day.day, kinds:) if kinds.any?
      end
    end

    # The newer update time of the latest day's route shapes, nil without one.
    def shape_updated_at = @days.empty? ? nil : shape_rows.fetch(@days.last.id, []).map(&:last).max

    private

    # A day stored before the published tables existed has no rows, which says
    # nothing about the schedule, so it is left out and the next day with rows
    # compares with the last one before it.
    def published_change_ids
      @published_change_ids ||= @days.select(&:published_schedule_day).each_cons(2).filter_map do |previous, day|
        day.id if published_rows(previous) != published_rows(day)
      end
    end

    # Every row of both tables, of every date value and sub-route, in a fixed order.
    def published_rows(day) = [ headway_rows[day.id]&.sort, departure_rows[day.id]&.sort ]

    def headway_rows
      @headway_rows ||= by_day(RouteDayPublishedHeadway.where(route_day_id: ids)
        .pluck(:route_day_id, :route_id, :path_attribute_id, :date_value, :start_minute, :end_minute, :low_minutes, :high_minutes))
    end

    def departure_rows
      @departure_rows ||= by_day(RouteDayPublishedDeparture.where(route_day_id: ids).pluck(:route_day_id, :route_id, :path_attribute_id, :date_value, :minute))
    end

    # The stops of the route day's own route; a member route's stop list is left out.
    def stop_rows
      @stop_rows ||= by_day(RouteDayStop.joins(:route_day).where(route_day_id: ids).where("route_day_stops.route_id = route_days.route_id")
        .order(:go_back, :seq).pluck(:route_day_id, :go_back, :seq, :stop_name, :stop_location_id))
    end

    def shape_rows
      @shape_rows ||= by_day(RouteDayShape.where(route_day_id: ids).order(:go_back).pluck(:route_day_id, :go_back, :shape_updated_at))
    end

    def by_day(rows) = rows.group_by(&:first).transform_values { |day_rows| day_rows.map { it.drop(1) } }

    def ids = @days.map(&:id)
  end
end
