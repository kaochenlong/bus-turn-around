# frozen_string_literal: true

# The trip counts and three key numbers over the covered days. Every key
# number is a value a table below already shows, taken from the same objects
# and written in the same format: the p50 and the share under 15 minutes of
# the layover row of every stopping end, and each direction's MRT overlap at
# 500 metres. Each links to its block; none is marked as meeting or missing a
# threshold.
class RouteSummaryComponent < ApplicationComponent
  def initialize(summary:, layover_stats:, ends:, mrt_overlap:)
    @summary = summary
    @layover_stats = layover_stats
    @ends = ends
    @mrt_overlap = mrt_overlap
  end

  def trips = @trips ||= @summary.trips

  def complete_trips = @complete_trips ||= @summary.complete_trips

  # Without a stopping end, a statement takes the place of the two layover numbers.
  def stopping_end? = @ends.stopping_go_backs.any?

  # The layover table's rows of the stopping ends. An end without a row (the
  # latest day has no stops) has no line here either.
  def stopping_rows = @stopping_rows ||= @layover_stats.rows.select { @ends.stopping?(it.go_back) }

  def p50(row) = row.percentiles[LayoverTableComponent::P50]

  def short_minutes = RoutePage::LayoverStats::SHORT_MINUTES

  def mrt_meters = RoutePage::MrtOverlap::STRETCH_THRESHOLD

  # A direction's overlap share at mrt_meters, as the overlap table shows it;
  # nil when the days need to be loaded again, since the table then shows no
  # share, or when the latest day has no stops in that direction.
  def mrt_share(go_back)
    return if @mrt_overlap.needs_reload?

    mrt_directions[go_back]&.shares&.fetch(mrt_meters)
  end

  private

  def mrt_directions = @mrt_directions ||= @mrt_overlap.directions.index_by(&:go_back)
end
