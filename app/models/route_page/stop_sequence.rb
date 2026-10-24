module RoutePage
  # The stop sequence of the latest of the given route days, as in the
  # route-page spec's stop sequence block: per direction, the page route's
  # stop names in sequence order, the first stop of the other direction, where
  # the next trip starts, and a note for every member route whose stops of
  # that direction differ from the page route's. The stops come from the
  # static snapshot of that day.
  class StopSequence
    Direction = Data.define(:go_back, :stop_names, :next_first_stop, :member_notes)

    # A member route's difference from the page route in one direction: the
    # page route's stops it does not serve, in page sequence order, and the
    # stops it serves instead, in its own sequence order, compared by stop
    # location.
    MemberNote = Data.define(:name, :route_id, :skipped_stops, :added_stops)

    Stop = Data.define(:route_id, :go_back, :seq, :name, :location_id)
    private_constant :Stop

    # The static snapshot day of the latest of the days; nil without days.
    attr_reader :static_day

    def initialize(route_days)
      # reorder, not order: the page passes the days already ordered oldest first.
      @latest_id, @static_day, @route_id, @member_names = route_days.reorder(day: :desc).pick(:id, :static_day, :route_id, :member_names)
    end

    # Every direction with page route stops on the latest of the days, in
    # direction order; the other direction's first stop is nil when it has no
    # stops. Read once.
    def directions
      @directions ||= begin
        by_route = latest_stops.group_by(&:route_id)
        page = (by_route[@route_id] || []).group_by(&:go_back)
        page.map do |go_back, stops|
          Direction.new(go_back:, stop_names: stops.map(&:name), next_first_stop: page[1 - go_back]&.first&.name,
                        member_notes: member_notes(go_back, stops, by_route))
        end
      end
    end

    def any? = directions.any?

    private

    # Every stop stored for the latest of the days, of the page route and its
    # member routes, in direction and sequence order; one query.
    def latest_stops
      RouteDayStop.where(route_day_id: @latest_id).order(:go_back, :seq).pluck(:route_id, :go_back, :seq, :stop_name, :stop_location_id)
                  .map { Stop.new(*it) }
    end

    # The members named on the day, by Id, whose stops of the direction do
    # not cover the same locations as the page route's.
    def member_notes(go_back, page_stops, by_route)
      (@member_names || {}).sort_by { |route_id, _| Integer(route_id) }.filter_map do |route_id, name|
        member_stops = (by_route[Integer(route_id)] || []).select { it.go_back == go_back }
        skipped = page_stops.reject { |page_stop| member_stops.any? { it.location_id == page_stop.location_id } }
        added = member_stops.reject { |member_stop| page_stops.any? { it.location_id == member_stop.location_id } }
        next if skipped.empty? && added.empty?

        MemberNote.new(name:, route_id: Integer(route_id), skipped_stops: skipped.map(&:name), added_stops: added.map(&:name))
      end
    end
  end
end
