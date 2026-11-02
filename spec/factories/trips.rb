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
FactoryBot.define do
  # A complete outbound trip of a stored day: by default TEST-0001 from 06:00, 50
  # minutes, on the route day's own route, with every one of five stops observed.
  factory :trip do
    route_day
    bus_id { "TEST-0001" }
    route_id { route_day.route_id }
    path_attribute_id { route_id }
    go_back { 0 }
    band { "other" }
    start_time { Time.zone.parse("#{route_day.day} 06:00") }
    end_time { start_time + 50.minutes }
    first_seq { 0 }
    last_seq { 4 }
    n_events { 10 }
    n_stops_observed { 5 }
    completeness { "complete" }
    start_from_arrival { false }
    end_from_departure { false }
  end
end
