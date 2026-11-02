# frozen_string_literal: true

# A stopping end's share of layovers under 15 minutes per Taipei hour the vehicle
# came back: one column per hour with the share and the count printed under it. An
# hour with few layovers says little, so its column is drawn apart.
class MonthCardHourShareChartComponent < MonthCardChartComponent
  WIDTH = 343
  LEFT = 44
  RIGHT = 2
  TOP = 8
  PLOT_HEIGHT = 98
  LINE = 13
  MAX_BAR = 12
  CORNER = 3
  TICKS = [ 0, 50, 100 ].freeze
  MIN_LAYOVERS = 10

  def initialize(rows:, go_back:)
    @rows = rows
    @go_back = go_back
  end

  attr_reader :rows, :go_back

  def height = TOP + PLOT_HEIGHT + (LINE * 3) + 6

  def base = TOP + PLOT_HEIGHT

  def tick_y(tick) = (TOP + (PLOT_HEIGHT * (1 - (tick / 100.0)))).round(1)

  def row_labels = [ t(".hour"), t(".share"), t(".count") ]

  def few?(row) = row.n_layovers < MIN_LAYOVERS

  # The middle of a row's column.
  def center(index) = (LEFT + (band * index) + (band / 2)).round(1)

  def percent(row) = (row.short_share * 100).round

  def column_path(row, index)
    column_height = PLOT_HEIGHT * row.short_share
    radius = [ CORNER, column_height ].min
    x = center(index) - (bar / 2)
    side = column_height - radius
    top = bar - (2 * radius)
    "M#{x.round(1)} #{base}v-#{side.round(1)}q0 -#{radius.round(1)} #{radius.round(1)} -#{radius.round(1)}h#{top.round(1)}q#{radius.round(1)} 0 #{radius.round(1)} #{radius.round(1)}v#{side.round(1)}z"
  end

  def column_fill(row) = few?(row) ? FAINT : SERIES_FIRST

  private

  def band = (WIDTH - LEFT - RIGHT).fdiv(rows.size)

  def bar = [ MAX_BAR, band - 3 ].min
end
