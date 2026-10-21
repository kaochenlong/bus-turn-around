# The route page: which routes have one, and the queries behind it.
module RoutePage
  def self.route_ids = Rails.application.config_for(:route_page).fetch(:route_ids)
end
