# A stop of the route on that day: its direction, seqNo and name.
# == Schema Information
#
# Table name: route_day_stops
#
#  id           :bigint           not null, primary key
#  go_back      :integer          not null
#  seq          :integer          not null
#  stop_name    :string           not null
#  route_day_id :bigint           not null
#
# Indexes
#
#  index_route_day_stops_on_route_day_id_and_go_back_and_seq  (route_day_id,go_back,seq) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
class RouteDayStop < ApplicationRecord
  belongs_to :route_day
end
