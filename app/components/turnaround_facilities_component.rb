# frozen_string_literal: true

# The turnaround facilities of both ends, as in the turnaround-facilities
# spec: where each end's location comes from with its check numbers, the
# toilet places within 300 and 500 metres, the nearest one, every place within
# 500 metres in a list closed by default, and the days the location and the
# toilet snapshot come from. Only numbers: nothing says whether the toilets
# are enough, and no colour marks a count.
class TurnaroundFacilitiesComponent < ApplicationComponent
  # Without end_map the parts carry no map, as when the page has no map to give.
  def initialize(facilities:, end_map: nil)
    @facilities = facilities
    @end_map = end_map
  end

  # The map of one end, drawn at the end of its part.
  def map_end(go_back) = @end_map&.ends&.find { it.go_back == go_back }

  def needs_reload? = @facilities.needs_reload?

  def ends = @facilities.ends

  def thresholds = RoutePage::Facilities::THRESHOLDS

  def main_threshold = RoutePage::Facilities::MAIN_THRESHOLD

  # Every place within this distance is listed.
  def list_radius = thresholds.max

  def located_radius = RoutePage::Facilities::LOCATED_RADIUS_METERS

  def meters(value) = format("%.1f", value)

  # A number on the page, marked with what it is.
  def value(name, text) = tag.span(text, data: { value: name })
end
