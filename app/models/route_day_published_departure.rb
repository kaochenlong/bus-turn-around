# One scheduled departure of a route Id on a route day, as defined by the
# published-schedule spec: which sub-route and date value of the day's static
# snapshot it came from, and its minute of the day.
# == Schema Information
#
# Table name: route_day_published_departures
#
#  id                :bigint           not null, primary key
#  date_value        :integer          not null
#  minute            :integer          not null
#  path_attribute_id :integer          not null
#  route_day_id      :bigint           not null
#  route_id          :integer          not null
#
# Indexes
#
#  index_route_day_published_departures_on_day_route_value  (route_day_id,route_id,date_value)
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
class RouteDayPublishedDeparture < ApplicationRecord
  belongs_to :route_day
end
