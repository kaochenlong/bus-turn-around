# == Schema Information
#
# Table name: route_day_depots
#
#  id            :bigint           not null, primary key
#  n_buses       :integer          not null
#  n_trips       :integer          not null
#  provider_name :string           not null
#  station_name  :string           not null
#  route_day_id  :bigint           not null
#  station_id    :integer          not null
#
# Indexes
#
#  index_route_day_depots_on_route_day_id_and_station_id  (route_day_id,station_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
FactoryBot.define do
  # One depot of a stored day: by default the fixture day's only depot, 測試客運
  # 測試站 (StationID 19001), with 4 vehicles and 27 trips.
  factory :route_day_depot do
    route_day
    station_id { 19001 }
    provider_name { "測試客運" }
    station_name { "測試站" }
    n_buses { 4 }
    n_trips { 27 }
  end
end
