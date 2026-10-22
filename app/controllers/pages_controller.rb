# The home page: which routes have a route page and how recent their stored
# data is. It shows no metric of its own.
class PagesController < ApplicationController
  def home
    @route_list = HomePage::RouteList.new
  end
end
