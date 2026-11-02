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
FactoryBot.define do
  # One scheduled departure of a stored day: by default a Monday's 22:30 of route 9001.
  factory :route_day_published_departure do
    route_day
    route_id { 9001 }
    path_attribute_id { route_id }
    date_value { 2 }
    minute { 1350 }
  end
end
