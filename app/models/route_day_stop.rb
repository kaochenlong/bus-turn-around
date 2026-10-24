# A stop of the route on that day: its direction, seqNo and name.
# == Schema Information
#
# Table name: route_day_stops
#
#  id                  :bigint           not null, primary key
#  go_back             :integer          not null
#  latitude            :float
#  longitude           :float
#  nearest_exit_meters :float
#  nearest_exit_name   :string
#  seq                 :integer          not null
#  stop_name           :string           not null
#  route_day_id        :bigint           not null
#  route_id            :integer          not null
#  stop_location_id    :integer
#
# Indexes
#
#  index_route_day_stops_on_route_day_route_direction_seq  (route_day_id,route_id,go_back,seq) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
class RouteDayStop < ApplicationRecord
  belongs_to :route_day

  # A stop belongs to its route day's route unless it comes from a member
  # route's stop list; the loader writes the route Id itself.
  before_validation { self.route_id ||= route_day&.route_id }
end
