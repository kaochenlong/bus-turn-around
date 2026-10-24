# == Schema Information
#
# Table name: route_day_shapes
#
#  id               :bigint           not null, primary key
#  go_back          :integer          not null
#  points           :jsonb            not null
#  shape_updated_at :timestamptz      not null
#  route_day_id     :bigint           not null
#
# Indexes
#
#  index_route_day_shapes_on_route_day_id_and_go_back  (route_day_id,go_back) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
FactoryBot.define do
  # One direction's route shape of a stored day: by default direction 0 of
  # route 9001 as on the fixture day, from 甲站 to 戊站.
  factory :route_day_shape do
    route_day
    go_back { 0 }
    shape_updated_at { Time.zone.parse("2023-12-29 09:46:21") }
    points { [ [ 25.05, 121.5 ], [ 25.0525, 121.5 ], [ 25.055, 121.5 ], [ 25.0575, 121.5 ], [ 25.06, 121.5 ] ] }
  end
end
