module RoutePage
  # The stop sequence of the latest of the given route days, as in the
  # route-page spec's stop sequence block: per direction, the stop names in
  # sequence order and the first stop of the other direction, where the next
  # trip starts. The stops come from the static snapshot of that day.
  class StopSequence
    Direction = Data.define(:go_back, :stop_names, :next_first_stop)

    # The static snapshot day of the latest of the days; nil without days.
    attr_reader :static_day

    def initialize(route_days)
      # reorder, not order: the page passes the days already ordered oldest first.
      @latest_id, @static_day = route_days.reorder(day: :desc).pick(:id, :static_day)
    end

    # Every direction with stops on the latest of the days, in direction order;
    # the other direction's first stop is nil when it has no stops. Read once.
    def directions
      @directions ||= begin
        names = RouteDayStop.where(route_day_id: @latest_id).order(:go_back, :seq).pluck(:go_back, :stop_name)
                            .group_by(&:first).transform_values { it.map(&:last) }
        names.map { |go_back, stop_names| Direction.new(go_back:, stop_names:, next_first_stop: names[1 - go_back]&.first) }
      end
    end

    def any? = directions.any?
  end
end
