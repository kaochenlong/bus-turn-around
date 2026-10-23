# frozen_string_literal: true

# Layovers per direction of the ending trip, so each end of the route has its
# own row, named after the last stop of that direction and labelled with the
# nature of that end: buses stop there, or drive on to the first stop of the
# next trip, which makes its layovers no rest opportunity.
class LayoverTableComponent < ApplicationComponent
  # The position of p50 in a row's percentiles.
  P50 = RoutePage::LayoverStats::PERCENTILE_LEVELS.index(0.5)

  def initialize(layover_stats:, ends:)
    @layover_stats = layover_stats
    @ends = ends
  end

  def rows = @rows ||= @layover_stats.rows

  def nature(row) = @ends.nature(row.go_back)

  def pass_through? = @ends.pass_through?

  # The summary's key numbers come from a stopping end's p50 and share under
  # SHORT_MINUTES; those cells are bold, so readers find them in the table.
  def key_cell_class(row) = ("font-semibold text-slate-900" if @ends.stopping?(row.go_back))

  def short_minutes = RoutePage::LayoverStats::SHORT_MINUTES

  # p10, p50 and p90, the column names of a row's percentiles.
  def percentile_labels = RoutePage::LayoverStats::PERCENTILE_LEVELS.map { "p#{(it * 100).round}" }
end
