# The home page: which routes have a route page, how recent their stored data
# is, and one figure per stopping end on the latest day: the share of layovers
# under 15 minutes. It shows no other metric.
class PagesController < ApplicationController
  def home
    @route_list = HomePage::RouteList.new
  end
end
