# frozen_string_literal: true

# The top of a route page: the route, the range switch, the covered days with
# their day type and notes, and a link to the other day type, or, when the
# selected day has not been stored, the days that have.
class RouteCoverageComponent < ApplicationComponent
  def initialize(coverage:)
    @coverage = coverage
  end

  # The covered route days, oldest first, read once for the list and the title.
  def covered = @covered ||= @coverage.route_days.to_a

  def route_day = covered.last

  def range_options = RoutePage::Coverage::RANGES.keys

  # Where the link to the other day type goes; nil when there is no stored day
  # of the other type on or before the selected day.
  def other_type_day = @coverage.other_type_day

  def other_day_type = @coverage.day_type_on(other_type_day)

  def range_path(range) = helpers.route_path(@coverage.route_id, day: @coverage.day&.iso8601, range:)

  def day_path(day) = helpers.route_path(@coverage.route_id, day: day.iso8601, range: @coverage.range)
end
