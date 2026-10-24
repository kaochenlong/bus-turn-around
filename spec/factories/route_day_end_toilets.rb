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
FactoryBot.define do
  # A toilet stored for an end: by default the nearest toilet of the fixture's
  # 戊站 end.
  factory :route_day_end_toilet do
    route_day_end
    name { "戊站公園-男廁" }
    category { "公園" }
    address { "臺北市測試區戊路2號" }
    latitude { 25.062686 }
    longitude { 121.5003 }
    meters { 251.7 }
  end
end
