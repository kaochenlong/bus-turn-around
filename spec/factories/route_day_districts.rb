# == Schema Information
#
# Table name: route_day_districts
#
#  id           :bigint           not null, primary key
#  county       :string           not null
#  n_locations  :integer          not null
#  qualifies    :boolean          not null
#  share        :float            not null
#  town         :string           not null
#  route_day_id :bigint           not null
#
# Indexes
#
#  index_route_day_districts_on_route_day_id_and_county_and_town  (route_day_id,county,town) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
FactoryBot.define do
  # One district of a stored day: by default the fixture day's 臺北市 測試區,
  # 9 of the route's 10 stop locations, qualifying.
  factory :route_day_district do
    route_day
    county { "臺北市" }
    town { "測試區" }
    n_locations { 9 }
    share { 0.9 }
    qualifies { true }
  end
end
