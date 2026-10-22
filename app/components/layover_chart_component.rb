# frozen_string_literal: true

# The layovers of each direction of the ending trip as a horizontal bar chart
# in the health card's bins, so the two ends of the route can be compared at a
# glance. Each title states whether buses stop at that end or drive on to the
# next trip. Bars are scaled to the largest bin of their own direction; a
# divider separates the bins under 15 minutes from the rest, without marking
# either side as compliant.
class LayoverChartComponent < ApplicationComponent
  WIDTH = 460
  LABEL_WIDTH = 64
  BAR_MAX = 300
  ROW = 26
  BAR_HEIGHT = 16
  DIVIDER_MINUTES = RoutePage::LayoverStats::SHORT_MINUTES

  def initialize(layover_distribution:, ends:)
    @layover_distribution = layover_distribution
    @ends = ends
  end

  def directions = @directions ||= @layover_distribution.directions

  def nature(direction) = @ends.nature(direction.go_back)

  def bounds = RoutePage::LayoverDistribution::BIN_LOWER_BOUNDS

  def height = (bounds.size * ROW) + 4

  def bar_x = LABEL_WIDTH + 4

  def row_y(index) = (index * ROW) + 4

  def bar_width(direction, count)
    largest = direction.counts.max
    largest.zero? ? 0 : (BAR_MAX * count.fdiv(largest)).round(1)
  end

  # The line between the last bin under DIVIDER_MINUTES and the first from it.
  def divider_y = row_y(bounds.index(DIVIDER_MINUTES)) - ((ROW - BAR_HEIGHT) / 2)

  def bin_label(index)
    upper = bounds[index + 1]
    upper ? "#{bounds[index]}–#{upper}" : "#{bounds[index]}+"
  end

  def empty?(direction) = direction.counts.sum.zero?

  def aria_label(direction)
    bins = direction.counts.each_with_index.map { |count, index| t(".bin_count", bin: bin_label(index), count:) }
    t(".aria", direction: t(".directions.#{direction.go_back}"), bins: bins.join("、"))
  end
end
