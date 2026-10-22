# frozen_string_literal: true

# The load profile of each direction as a line of median on-board counts
# along the stop sequence, one time band shown at a time, with the MRT overlap
# stretches drawn as shaded spans. All bands of a direction share one vertical
# scale so switching bands keeps heights comparable. A stop without a count in
# a band breaks that band's line; nothing is filled in.
class LoadChartComponent < ApplicationComponent
  BANDS = %w[morning_peak daytime evening_peak other].freeze
  DEFAULT_BAND = BANDS.first
  SCALE_STEP = 10
  WIDTH = 720
  HEIGHT = 230
  LEFT = 36
  RIGHT = 12
  TOP = 22
  BOTTOM = 34

  Chart = Data.define(:go_back, :stops, :medians, :ranges)

  def initialize(load_profile:, mrt_overlap:)
    @load_profile = load_profile
    @mrt_overlap = mrt_overlap
  end

  def charts
    @charts ||= begin
      medians = @load_profile.rows.group_by(&:go_back)
      ranges = @mrt_overlap.stretch_ranges
      @load_profile.stops.group_by(&:go_back).map do |go_back, stops|
        Chart.new(go_back:, stops:, medians: Array(medians[go_back]).to_h { [ [ it.band, it.seq ], it.median ] },
                  ranges: ranges.fetch(go_back, []))
      end
    end
  end

  # The largest median of the direction in any band, rounded up to a whole
  # SCALE_STEP; SCALE_STEP when the direction has no count.
  def scale_top(chart)
    largest = chart.medians.values.max.to_f
    [ (largest / SCALE_STEP).ceil * SCALE_STEP, SCALE_STEP ].max
  end

  def points(chart, band)
    chart.stops.filter_map do |stop|
      median = chart.medians[[ band, stop.seq ]]
      [ stop.seq, median ] if median
    end
  end

  # Runs of points at adjacent stops; a stop without a count starts a new run.
  def segments(chart, band)
    order = chart.stops.each_with_index.to_h { |stop, index| [ stop.seq, index ] }
    points(chart, band).slice_when { |a, b| order[b.first] != order[a.first] + 1 }.to_a
  end

  def x(chart, seq)
    index = chart.stops.index { it.seq == seq }
    return LEFT + (plot_width / 2.0) if chart.stops.size == 1

    (LEFT + (plot_width * index.fdiv(chart.stops.size - 1))).round(1)
  end

  def y(chart, value) = (TOP + (plot_height * (1 - value.fdiv(scale_top(chart))))).round(1)

  def step(chart) = chart.stops.size > 1 ? plot_width.fdiv(chart.stops.size - 1) : plot_width

  def span_x(chart, range) = (x(chart, range.first) - (step(chart) / 2)).round(1)

  def span_width(chart, range) = (x(chart, range.last) - x(chart, range.first) + step(chart)).round(1)

  def stop_name(chart, seq) = chart.stops.find { it.seq == seq }&.stop_name

  def polyline(chart, segment) = segment.map { |seq, median| "#{x(chart, seq)},#{y(chart, median)}" }.join(" ")

  def plot_width = WIDTH - LEFT - RIGHT

  def plot_height = HEIGHT - TOP - BOTTOM

  def baseline = TOP + plot_height
end
