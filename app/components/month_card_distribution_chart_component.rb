# frozen_string_literal: true

# A stopping end's layovers in the bins of layover-metrics, as horizontal bars with
# a line at 15 minutes. The bins under it take the series colour; the line marks a
# boundary, not a verdict.
class MonthCardDistributionChartComponent < MonthCardChartComponent
  WIDTH = 300
  ROW = 25
  LEFT = 62
  RIGHT = 40
  BAR_HEIGHT = 16
  CORNER = 3
  # The room under the line for its label: the bar above it may be the longest, with
  # its count right where the label would otherwise be.
  BOUNDARY_GAP = 13
  BOUNDS = RoutePage::LayoverDistribution::BIN_LOWER_BOUNDS

  # One bin: its lower bound, label, count and vertical place.
  Bin = Data.define(:lower, :label, :count, :y, :width) do
    def short? = lower < RoutePage::LayoverStats::SHORT_MINUTES
  end

  def initialize(counts:)
    @counts = counts
  end

  def height = (ROW * BOUNDS.size) + 6 + BOUNDARY_GAP

  def bins
    largest = @counts.max
    BOUNDS.each_index.map do |index|
      count = @counts[index]
      Bin.new(lower: BOUNDS[index], label: label(index), count:, y: bin_y(index), width: largest.zero? ? 0 : ((WIDTH - LEFT - RIGHT) * count.fdiv(largest)).round(1))
    end
  end

  # A bar with a rounded end; a very short one still shows as a sliver.
  def bar_path(bin)
    straight = [ bin.width - CORNER, 0 ].max
    "M#{LEFT} #{bin.y}h#{straight}q#{CORNER} 0 #{CORNER} #{CORNER}v#{BAR_HEIGHT - (2 * CORNER)}q0 #{CORNER} -#{CORNER} #{CORNER}h-#{straight}z"
  end

  def bin_fill(bin) = bin.short? ? SERIES_FIRST : FAINT

  # Where the line between the bins under 15 minutes and the others runs.
  def boundary_y = (short_bins * ROW) + 1

  def boundary_label_y = boundary_y + 10

  def boundary_label = t(".boundary", minutes: RoutePage::LayoverStats::SHORT_MINUTES)

  def aria_label = bins.map { t(".bin_aria", label: it.label, count: it.count) }.join("、")

  private

  def short_bins = BOUNDS.count { it < RoutePage::LayoverStats::SHORT_MINUTES }

  def bin_y(index) = (index * ROW) + 3 + (index >= short_bins ? BOUNDARY_GAP : 0)

  def label(index)
    upper = BOUNDS[index + 1]
    upper ? t(".bin", lower: BOUNDS[index], upper:) : t(".last_bin", lower: BOUNDS[index])
  end
end
