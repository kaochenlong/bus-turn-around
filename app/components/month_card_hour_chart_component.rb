# frozen_string_literal: true

# A month card's chart over the hours of a day: lines with their points, grey bands
# for what was published, shaded hours and notes above the bands. The vertical scale
# fits the figures, so a route with a few vehicles and one with sixty both fill it.
class MonthCardHourChartComponent < MonthCardChartComponent
  WIDTH = 673
  LEFT = 34
  RIGHT = 8
  TOP = 20
  BOTTOM = 22
  # Room above the top tick for the notes.
  HEADROOM = 0.12
  TICK_STEPS = [ 1, 2, 5, 10, 20, 50, 100, 200 ].freeze
  MAX_TICKS = 7
  SHADE = "#f1f5f9"
  BAND_OPACITY = 0.55

  # points are [hour, value], where hour 6.5 is the middle of the 06 hour.
  Series = Data.define(:key, :color, :points)
  Band = Data.define(:from_hour, :to_hour, :low, :high)
  Note = Data.define(:hour, :value, :text)

  # Round ticks that cover the figures, as few as stay readable.
  def self.ticks_for(low, high)
    return [ low, low + 1 ] if high <= low

    step = TICK_STEPS.find { |candidate| ((high.fdiv(candidate).ceil * candidate) - (low.fdiv(candidate).floor * candidate)) / candidate < MAX_TICKS } || TICK_STEPS.last
    ((low.fdiv(step).floor * step)..(high.fdiv(step).ceil * step)).step(step).to_a
  end

  attr_reader :aria_label, :height, :ticks, :series, :shaded_hours, :notes

  # The axis runs from first_hour to last_hour, and is labelled up to the hour
  # before last_hour.
  def initialize(aria_label:, height:, first_hour:, last_hour:, ticks:, series: [], bands: [], shaded_hours: [], notes: [])
    @aria_label = aria_label
    @height = height
    @first_hour = first_hour
    @last_hour = last_hour
    @ticks = ticks
    @series = series
    @bands = bands
    @shaded_hours = shaded_hours
    @notes = notes
  end

  def hour_labels = (@first_hour...@last_hour).to_a

  def x(hour) = (LEFT + ((hour - @first_hour).fdiv(@last_hour - @first_hour) * plot_width)).round(1)

  def y(value) = (TOP + ((1 - (value - ticks.first).fdiv(top_value - ticks.first)) * plot_height)).round(1)

  def base = y(ticks.first)

  def plot_top = TOP

  def plot_height = height - TOP - BOTTOM

  def right_edge = WIDTH - RIGHT

  def points_text(line) = line.points.map { |hour, value| "#{x(hour)},#{y(value)}" }.join(" ")

  # The bands inside the axis, cut to it.
  def visible_bands
    @bands.filter_map do |band|
      from, to = [ band.from_hour, @first_hour ].max, [ band.to_hour, @last_hour ].min
      band.with(from_hour: from, to_hour: to) if to > from
    end
  end

  private

  def plot_width = WIDTH - LEFT - RIGHT

  def top_value = ticks.last + ((ticks.last - ticks.first) * HEADROOM)
end
