# How far and how long a trip ran between two placed stops, as defined by the
# stop-to-stop-speed spec.
# == Schema Information
#
# Table name: trip_stop_speeds
#
#  id      :bigint           not null, primary key
#  band    :string           not null
#  meters  :float            not null
#  seconds :integer          not null
#  seq     :integer          not null
#  trip_id :bigint           not null
#
# Indexes
#
#  index_trip_stop_speeds_on_trip_id_and_seq  (trip_id,seq) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (trip_id => trips.id) ON DELETE => cascade
#
class TripStopSpeed < ApplicationRecord
  belongs_to :trip
end
