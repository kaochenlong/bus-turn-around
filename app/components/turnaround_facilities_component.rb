# frozen_string_literal: true

# The turnaround facilities of both ends, as in the turnaround-facilities
# spec: where each end's location comes from with its check numbers, the
# toilet places within 300 and 500 metres, the nearest one, every place within
# 500 metres in a list closed by default, and the days the location and the
# toilet snapshot come from; after both ends, the depots the vehicles belong
# to with the inspection scores the evaluation report prints for them. Only
# numbers: nothing says whether the toilets are enough or a score is good,
# and no colour marks a count or a score.
class TurnaroundFacilitiesComponent < ApplicationComponent
  # Without end_map the parts carry no map, as when the page has no map to give.
  def initialize(facilities:, depots:, end_map: nil)
    @facilities = facilities
    @depots = depots
    @end_map = end_map
  end

  def depots = @depots

  # The term of the inspection scores as the page names it, such as 115 年第 1 期.
  def term_label = t(".term", year: depots.term.year, period: depots.term.period)

  # A depot by its operator and station, or by its StationID when the day's
  # static snapshot gave no names.
  def depot_name(depot)
    return t(".unnamed_depot", id: depot.station_id) unless depot.named?

    t(".depot_name", provider: depot.provider_name, station: depot.station_name)
  end

  # Both printed columns, or one when they are the same.
  def score_text(score) = score.columns.uniq.join("／")

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
