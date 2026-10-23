# The basemap tiles of the route page maps, as in the turnaround-map spec:
# the tile address template, the attribution text the map and every page
# footer show, and the maximum zoom, from config/map.yml for the current
# environment. A missing key is a configuration error that names the key, so
# the page fails where the configuration is wrong rather than drawing a map
# without a source.
module MapTiles
  KEYS = %i[url attribution max_zoom].freeze

  # The configuration lacks one of KEYS for the current environment.
  class InvalidConfiguration < StandardError; end

  Tiles = Data.define(*KEYS)

  def self.url = current.url

  def self.attribution = current.attribution

  def self.max_zoom = current.max_zoom

  # The tiles a map.yml gives the current environment, its shared section
  # merged in.
  def self.load(path = Rails.root.join("config/map.yml"))
    tiles = Rails.application.config_for(Pathname(path)).fetch(:tiles, {})
    missing = KEYS.reject { tiles[it].present? }
    raise InvalidConfiguration, "#{path} 的 tiles 缺 #{missing.join('、')}" if missing.any?

    Tiles.new(**tiles.slice(*KEYS))
  end

  def self.current = @current ||= load
  private_class_method :current
end
