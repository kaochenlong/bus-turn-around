# frozen_string_literal: true

# The stop speeds of the covered days (RoutePage::StopSpeeds) as one grid per
# direction: a row per time band, a cell per leg in stop order, shaded by its
# level or drawn as an outline when it is a small sample or has no rows. Under
# the grid a line runs through a mark for every stop, and each stop name is
# written top to bottom below its mark, like the route on a Taipei bus stop
# sign. The numbers are in a table inside a closed disclosure. The grids are
# inline SVG drawn by the server, without a chart library or tooltips
# (route-page-charts); the table is their text view.
class StopSpeedGridComponent < ApplicationComponent
  BANDS = RoutePage::StopSpeeds::BANDS
  CELL = 18
  GAP = 3
  PITCH = CELL + GAP
  RADIUS = 4
  # Room for the band names left of the grid and above its first row.
  LEFT = 52
  TOP = 2
  BAND_NAME_GAP = 6
  # A stop's mark sits at the gap between its legs: a 4 px circle with a 2 px
  # stroke (the template's stroke-2), 10 px across, its top 12 px below the
  # grid.
  MARK_RADIUS = 4
  MARK_STROKE = 2
  MARK_TOP = 12
  # Stop names start 8 px below their marks; a name is taken as one font size
  # per character, which a CJK name fills.
  LABEL_FONT = 14
  LABEL_GAP = 8
  # One hue from light to dark, the darkest the slowest (dataviz: a sequential
  # ramp is one hue with lightness falling step by step).
  LEVEL_FILLS = { 1 => "fill-teal-200", 2 => "fill-teal-400", 3 => "fill-teal-600", 4 => "fill-teal-800" }.freeze
  LEVEL_SWATCHES = { 1 => "bg-teal-200", 2 => "bg-teal-400", 3 => "bg-teal-600", 4 => "bg-teal-800" }.freeze
  OUTLINE = "fill-white stroke-slate-300"

  def initialize(stop_speeds:)
    @stop_speeds = stop_speeds
  end

  def available? = @stop_speeds.available?

  def directions = @stop_speeds.directions

  def bands = BANDS

  # The stop names of a direction's legs: each leg's first stop, then the
  # last leg's last stop.
  def stop_names(direction) = [ direction.legs.first.from_name, *direction.legs.map(&:to_name) ]

  # Wide enough for the last stop's name, which is centred on its mark.
  def width(direction) = (boundary_x(direction.legs.size) + (LABEL_FONT / 2.0)).ceil

  def height(direction) = label_y + label_length(direction) + 2

  def cell_x(index) = LEFT + (index * PITCH)

  def cell_y(band_index) = TOP + (band_index * PITCH)

  def band_name_x = LEFT - BAND_NAME_GAP

  def band_name_y(band_index) = cell_y(band_index) + (CELL / 2)

  # The x of the gap before leg `index`, where the stop between two legs is.
  def boundary_x(index) = LEFT + (index * PITCH) - (GAP / 2.0)

  def mark_y = TOP + (bands.size * PITCH) - GAP + MARK_TOP + mark_reach

  def label_y = mark_y + mark_reach + LABEL_GAP

  # The first and last stops of a direction are filled; the others are rings.
  def terminal?(direction, index) = index.zero? || index == direction.legs.size

  def mark_class(direction, index) = terminal?(direction, index) ? "fill-slate-600 stroke-slate-600" : "fill-white stroke-slate-400"

  # The classes and data attributes of a cell: its level's fill, or the outline
  # of a small sample or of a cell without rows.
  def cell_class(cell) = cell.level ? LEVEL_FILLS.fetch(cell.level) : OUTLINE

  # The same for a square of the narrow rows, which is HTML, not SVG.
  def square_class(cell) = cell.level ? LEVEL_SWATCHES.fetch(cell.level) : "border border-slate-300 bg-white"

  def cell_data(cell)
    if cell.level then { level: cell.level }
    elsif cell.small_sample then { small_sample: true }
    else { no_speed: true }
    end
  end

  # The three speeds between the four levels, fastest first.
  def level_bounds(direction) = direction.level_ranges.first(3).map(&:first)

  def decimal(value) = format("%.1f", value)

  def whole(value) = format("%.0f", value)

  private

  def label_length(direction) = stop_names(direction).map(&:length).max * LABEL_FONT

  # From a mark's centre to the outer edge of its stroke.
  def mark_reach = MARK_RADIUS + (MARK_STROKE / 2)
end
