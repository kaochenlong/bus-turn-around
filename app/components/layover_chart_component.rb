# frozen_string_literal: true

# The layovers of each direction of the ending trip as a horizontal bar chart
# in the health card's bins, so the two ends of the route can be compared at a
# glance. Each title states whether buses stop at that end or drive on to the
# next trip. Bars are scaled to the largest bin of their own direction; a
# divider separates the bins under 15 minutes from the rest, without marking
# either side as compliant. The divider sits in an extra gap between the two
# groups and stops at the end of the tracks, with its label right after it at
# the same height, so no bar or count, however long, reaches the label.
class LayoverChartComponent < ApplicationComponent
  WIDTH = 300
  LABEL_WIDTH = 40
  BAR_MAX = 190
  ROW = 30
  BAR_HEIGHT = 18
  # How much lower the bins from DIVIDER_MINUTES sit, making room for the label.
  DIVIDER_GAP = 14
  DIVIDER_MINUTES = RoutePage::LayoverStats::SHORT_MINUTES

  def initialize(layover_distribution:, ends:)
    @layover_distribution = layover_distribution
    @ends = ends
  end

  def directions = @directions ||= @layover_distribution.directions

  def nature(direction) = @ends.nature(direction.go_back)

  def bounds = RoutePage::LayoverDistribution::BIN_LOWER_BOUNDS

  def height = (bounds.size * ROW) + DIVIDER_GAP + 4

  def bar_x = LABEL_WIDTH + 8

  # Where every bar's track ends; the divider stops here.
  def track_end = bar_x + BAR_MAX

  def row_y(index) = (index * ROW) + 4 + (index >= divider_index ? DIVIDER_GAP : 0)

  # The baseline of a row's label and count, centred on its bar.
  def text_y(index) = row_y(index) + 14.5

  def bar_width(direction, count)
    largest = direction.counts.max
    largest.zero? ? 0 : (BAR_MAX * count.fdiv(largest)).round(1)
  end

  # The line midway between the bar of the last bin under DIVIDER_MINUTES and
  # the bar of the first bin from it.
  def divider_y = (row_y(divider_index - 1) + BAR_HEIGHT + row_y(divider_index)) / 2.0

  def bin_label(index)
    upper = bounds[index + 1]
    upper ? "#{bounds[index]}–#{upper}" : "#{bounds[index]}+"
  end

  def empty?(direction) = direction.counts.sum.zero?

  def aria_label(direction)
    bins = direction.counts.each_with_index.map { |count, index| t(".bin_count", bin: bin_label(index), count:) }
    t(".aria", direction: t(".directions.#{direction.go_back}"), bins: bins.join("、"))
  end

  private

  # The row of the first bin from DIVIDER_MINUTES.
  def divider_index = bounds.index(DIVIDER_MINUTES)
end
