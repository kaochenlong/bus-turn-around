# A public toilet within 500 metres of an end's location: one row of the toilet
# snapshot, a single toilet rather than a place.
# == Schema Information
#
# Table name: route_day_end_toilets
#
#  id               :bigint           not null, primary key
#  address          :string
#  category         :string
#  latitude         :float            not null
#  longitude        :float            not null
#  meters           :float            not null
#  name             :string           not null
#  route_day_end_id :bigint           not null
#
# Indexes
#
#  index_route_day_end_toilets_on_route_day_end_id  (route_day_end_id)
#
# Foreign Keys
#
#  fk_rails_...  (route_day_end_id => route_day_ends.id) ON DELETE => cascade
#
class RouteDayEndToilet < ApplicationRecord
  belongs_to :route_day_end
end
