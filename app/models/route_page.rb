# The route page: which routes have one, the nature of their two ends, and the
# queries behind it.
module RoutePage
  # The routes that have a page: the keys of config/route_page.yml. A route
  # listed under another route's member_routes has no page of its own.
  def self.route_ids = routes.keys

  def self.ends(route_id) = Ends.from_config(routes.dig(route_id, :ends), route_id:)

  # The route Ids a page counts as one route: the page route first, then the
  # member routes listed under it in config/route_page.yml, in that order. A
  # route the configuration does not mention is a page of itself alone. A
  # member that is the page route itself, a key of the route list, or listed
  # under another route too is a configuration error, raised wherever the
  # configuration is read: it is a verified fact, never an assumption.
  def self.member_route_ids(route_id)
    all = routes
    members = Array(all.dig(route_id, :member_routes))
    members.each do |member|
      invalid_member(route_id, member, "is the page route itself") if member == route_id
      invalid_member(route_id, member, "is also a key of the route list") if all.key?(member)
      invalid_member(route_id, member, "is listed under it more than once") if members.count(member) > 1
      elsewhere = all.except(route_id).select { |_, route| Array(route[:member_routes]).include?(member) }.keys
      invalid_member(route_id, member, "is also a member route of route #{elsewhere.join(', ')}") if elsewhere.any?
    end
    [ route_id, *members ]
  end

  # The page route a member route is counted with, or nil when the Id is not
  # listed under any route's member_routes.
  def self.member_of(route_id) = routes.find { |_, route| Array(route[:member_routes]).include?(route_id) }&.first

  def self.routes = Rails.application.config_for(:route_page).fetch(:routes)
  private_class_method :routes

  def self.invalid_member(route_id, member, reason)
    raise Ends::InvalidConfiguration, "route #{route_id}: member route #{member} in config/route_page.yml #{reason}"
  end
  private_class_method :invalid_member
end
