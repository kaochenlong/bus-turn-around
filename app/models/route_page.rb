# The route page: which routes have one, the nature of their two ends, and the
# queries behind it.
module RoutePage
  def self.route_ids = routes.keys

  def self.ends(route_id) = Ends.from_config(routes.dig(route_id, :ends), route_id:)

  def self.routes = Rails.application.config_for(:route_page).fetch(:routes)
  private_class_method :routes
end
