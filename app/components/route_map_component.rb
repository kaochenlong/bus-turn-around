# frozen_string_literal: true

# The route map of the stop sequence block, as in the route-shape spec: the
# map data as JSON, a sentence for as long as the map is not drawn, and an
# empty canvas that keeps its height; the routeMap Alpine component draws into
# it once the container scrolls into view. The container is hidden from
# assistive technology, because every stop is in the list below it; the line
# after it, which names the data source and when the office last updated it,
# is not hidden. Without a route shape on any covered day there is only a
# sentence saying so.
class RouteMapComponent < ApplicationComponent
  def initialize(route_shape:, tiles: MapTiles)
    @route_shape = route_shape
    @tiles = tiles
  end

  attr_reader :tiles

  def available? = @route_shape.available?

  # The map data for the drawing script, escaped so that a name holding
  # </script> cannot end the tag.
  def data_json = ERB::Util.json_escape(map_data.to_json)

  # The words the drawing script writes on the map, in the page's language,
  # each keyed by direction.
  def labels_json
    { directions: by_direction(".labels.directions"), firstStop: by_direction(".labels.first_stop"),
      lastStop: by_direction(".labels.last_stop") }.to_json
  end

  def updated_on = @route_shape.updated_on.iso8601

  private

  # camelCase keys, coordinates as numbers, and no vehicle field.
  def map_data
    { lines: @route_shape.lines.map { { goBack: it.go_back, points: it.points } },
      endStops: @route_shape.end_stops.map { { goBack: it.go_back, first: it.first.to_h, last: it.last.to_h } } }
  end

  def by_direction(key) = RoutePage::Ends::DIRECTIONS.to_h { [ it.to_s, t("#{key}.#{it}") ] }
end
