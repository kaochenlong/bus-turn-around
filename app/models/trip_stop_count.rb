# The on-board count of a trip at one stop, as defined by the load-profile spec.
# == Schema Information
#
# Table name: trip_stop_counts
#
#  id       :bigint           not null, primary key
#  on_board :integer          not null
#  seq      :integer          not null
#  trip_id  :bigint           not null
#
# Indexes
#
#  index_trip_stop_counts_on_trip_id_and_seq  (trip_id,seq) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (trip_id => trips.id) ON DELETE => cascade
#
class TripStopCount < ApplicationRecord
  belongs_to :trip
end
