# frozen_string_literal: true

# Layovers per direction of the ending trip, so each end of the route has its
# own row, named after the last stop of that direction and labelled with the
# nature of that end: buses stop there, or drive on to the first stop of the
# next trip, which makes its layovers no rest opportunity.
class LayoverTableComponent < ApplicationComponent
  NONE = "—"

  def initialize(layover_stats:, ends:)
    @layover_stats = layover_stats
    @ends = ends
  end

  def rows = @rows ||= @layover_stats.rows

  def nature(row) = @ends.nature(row.go_back)

  def pass_through? = @ends.pass_through?

  def minutes(value) = value.nil? ? NONE : format("%.1f", value)

  def share(value) = value.nil? ? NONE : format("%.1f%%", value * 100)

  def short_minutes = RoutePage::LayoverStats::SHORT_MINUTES
end
