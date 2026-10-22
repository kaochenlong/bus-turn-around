# frozen_string_literal: true

# The top of a route page: the route, the range switch and the covered days,
# or, when the selected day has not been stored, the days that have.
class RouteCoverageComponent < ApplicationComponent
  def initialize(coverage:)
    @coverage = coverage
  end

  def route_day = @route_day ||= @coverage.route_days.last

  def covered_days = @coverage.route_days.map(&:day)

  def range_options = RoutePage::Coverage::RANGES.keys

  def range_path(range) = helpers.route_path(@coverage.route_id, day: @coverage.day&.iso8601, range:)

  def day_path(day) = helpers.route_path(@coverage.route_id, day: day.iso8601, range: @coverage.range)
end
