# A depot the vehicles of a route day belong to, as defined by the
# turnaround-facilities spec: the StationID most of a trip's events carry, the
# operator and station names the day's GetProvider.gz gives it (empty strings
# when the snapshot had none) and the numbers of vehicles and trips that day.
# == Schema Information
#
# Table name: route_day_depots
#
#  id            :bigint           not null, primary key
#  n_buses       :integer          not null
#  n_trips       :integer          not null
#  provider_name :string           not null
#  station_name  :string           not null
#  route_day_id  :bigint           not null
#  station_id    :integer          not null
#
# Indexes
#
#  index_route_day_depots_on_route_day_id_and_station_id  (route_day_id,station_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
class RouteDayDepot < ApplicationRecord
  belongs_to :route_day
end
