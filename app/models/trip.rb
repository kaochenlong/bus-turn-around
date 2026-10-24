# A reconstructed trip, as defined by the trip-reconstruction spec. It carries
# the vehicle, which the route page never shows.
# == Schema Information
#
# Table name: trips
#
#  id                 :bigint           not null, primary key
#  band               :string           not null
#  completeness       :string           not null
#  end_from_departure :boolean          not null
#  end_time           :timestamptz      not null
#  first_seq          :integer          not null
#  go_back            :integer          not null
#  last_seq           :integer          not null
#  n_events           :integer          not null
#  n_stops_observed   :integer          not null
#  start_from_arrival :boolean          not null
#  start_time         :timestamptz      not null
#  bus_id             :string           not null
#  path_attribute_id  :integer          not null
#  route_day_id       :bigint           not null
#  route_id           :integer          not null
#
# Indexes
#
#  index_trips_on_route_day_id_and_bus_id_and_start_time  (route_day_id,bus_id,start_time) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
class Trip < ApplicationRecord
  belongs_to :route_day
  has_many :trip_stop_counts, dependent: nil

  # A trip belongs to its route day's route unless its events carried a
  # member route's Id; the loader writes the route Id itself.
  before_validation { self.route_id ||= route_day&.route_id }
end
