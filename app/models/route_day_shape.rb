# One direction's route shape on that day, as defined by the route-shape spec:
# the line 臺北市公共運輸處 registers for the route, not measured GPS, with the
# time the office last updated it and its points as [latitude, longitude]
# pairs in their original order.
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
class RouteDayShape < ApplicationRecord
  belongs_to :route_day
end
