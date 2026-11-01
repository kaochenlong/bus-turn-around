# One district of a route day, as defined by the stop-districts spec: the
# county and town, the number of the page route's stop locations in it, their
# share of all the page route's stop locations and whether that share reaches
# the threshold of analysis/params.sql. The home page's district filter lists
# the qualifying districts of each route's latest day.
# == Schema Information
#
# Table name: route_day_districts
#
#  id           :bigint           not null, primary key
#  county       :string           not null
#  n_locations  :integer          not null
#  qualifies    :boolean          not null
#  share        :float            not null
#  town         :string           not null
#  route_day_id :bigint           not null
#
# Indexes
#
#  index_route_day_districts_on_route_day_id_and_county_and_town  (route_day_id,county,town) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
class RouteDayDistrict < ApplicationRecord
  belongs_to :route_day
end
