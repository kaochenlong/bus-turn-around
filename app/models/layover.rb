# The time between the end of a trip and the start of the vehicle's next trip,
# as defined by the layover-metrics spec. Minutes come from the two times.
# == Schema Information
#
# Table name: layovers
#
#  id              :bigint           not null, primary key
#  end_time        :timestamptz      not null
#  go_back         :integer          not null
#  next_start_time :timestamptz      not null
#  bus_id          :string           not null
#  route_day_id    :bigint           not null
#
# Indexes
#
#  index_layovers_on_route_day_id  (route_day_id)
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
class Layover < ApplicationRecord
  belongs_to :route_day
end
