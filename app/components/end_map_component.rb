# frozen_string_literal: true

# One end's map container, as in the turnaround-map spec: the map data as JSON,
# a sentence for as long as the map is not drawn, and an empty canvas that keeps
# its height; the endMap Alpine component draws into it once the container
# scrolls into view. The container is hidden from assistive technology, because
# every number of the end is in the text above it; the coverage line after it
# is not hidden.
class EndMapComponent < ApplicationComponent
  def initialize(end:, tiles: MapTiles)
    # end is a Ruby keyword, so the argument can only be read through the binding.
    @map_end = binding.local_variable_get(:end)
    @tiles = tiles
  end

  attr_reader :tiles

  def go_back = @map_end.go_back

  # The map data for the drawing script, escaped so that a name holding
  # </script> cannot end the tag.
  def data_json = ERB::Util.json_escape(map_data.to_json)

  # The words the drawing script writes on the map, in the page's language.
  # The toilet line keeps {meters} and {count} for the script to fill.
  def labels_json
    { lastStop: t(".labels.last_stop"), nextFirstStop: t(".labels.next_first_stop"), location: t(".labels.location"),
      toilet: t(".labels.toilet"), few: t(".labels.few"), many: t(".labels.many") }.to_json
  end

  def no_reports? = @map_end.coverage_share.nil?

  def coverage_percent = "#{(@map_end.coverage_share * 100).round}%"

  def cells_beyond_extent = @map_end.cells_beyond_extent

  def extent_km = RoutePage::EndMap::EXTENT_METERS / 1000

  private

  # camelCase keys, coordinates as numbers, and no vehicle field.
  def map_data
    { goBack: @map_end.go_back, nature: @map_end.nature, lastStop: @map_end.last_stop&.to_h,
      nextFirstStop: @map_end.next_first_stop&.to_h, location: @map_end.location&.to_h, places: @map_end.places.map { place_data(it) },
      cells: @map_end.cells.map(&:to_h), cellsBeyondExtent: @map_end.cells_beyond_extent, cellDegrees: RoutePage::EndMap::CELL_DEGREES,
      extentMeters: RoutePage::EndMap::EXTENT_METERS, minZoom: RoutePage::EndMap::MIN_ZOOM,
      coverage: { recordsShown: @map_end.records_shown, recordsTotal: @map_end.records_total, share: @map_end.coverage_share } }
  end

  def place_data(place)
    { name: place.name, category: place.category, meters: place.meters, toilets: place.n_toilets, lat: place.latitude, lon: place.longitude }
  end
end
