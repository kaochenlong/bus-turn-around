# frozen_string_literal: true

# Layovers per direction of the ending trip, so each end of the route has its
# own row, named after the last stop of that direction.
class LayoverTableComponent < ApplicationComponent
  NONE = "—"

  def initialize(layover_stats:)
    @layover_stats = layover_stats
  end

  def rows = @rows ||= @layover_stats.rows

  def minutes(value) = value.nil? ? NONE : format("%.1f", value)

  def share(value) = value.nil? ? NONE : format("%.1f%%", value * 100)

  def short_minutes = RoutePage::LayoverStats::SHORT_MINUTES
end
