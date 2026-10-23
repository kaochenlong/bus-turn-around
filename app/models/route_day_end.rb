# One end of the route on that day, as defined by the turnaround-facilities
# spec: its last stop, where the buses stood still or the last stop for a
# pass-through end, the check numbers, and the toilets and standstill cells
# near it, which the database deletes with it.
# == Schema Information
#
# Table name: route_day_ends
#
#  id                   :bigint           not null, primary key
#  end_latitude         :float
#  end_longitude        :float
#  end_seq              :integer          not null
#  end_stop_meters      :float
#  end_stop_name        :string           not null
#  go_back              :integer          not null
#  latitude             :float
#  location_source      :string
#  longitude            :float
#  n_layovers           :integer          not null
#  n_located_layovers   :integer
#  n_standstill_records :integer          not null
#  route_day_id         :bigint           not null
#
# Indexes
#
#  index_route_day_ends_on_route_day_id_and_go_back  (route_day_id,go_back) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
class RouteDayEnd < ApplicationRecord
  belongs_to :route_day
  has_many :toilets, class_name: "RouteDayEndToilet", dependent: nil
  has_many :cells, class_name: "RouteDayEndCell", dependent: nil
end
