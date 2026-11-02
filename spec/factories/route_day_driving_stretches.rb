# == Schema Information
#
# Table name: route_day_driving_stretches
#
#  id           :bigint           not null, primary key
#  end_time     :timestamptz      not null
#  n_trips      :integer          not null
#  start_time   :timestamptz      not null
#  bus_id       :string           not null
#  route_day_id :bigint           not null
#
# Indexes
#
#  index_route_day_driving_stretches_on_day_bus_start  (route_day_id,bus_id,start_time) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
FactoryBot.define do
  # One stretch of a stored day: by default TEST-0001 for 100 minutes from 06:00.
  factory :route_day_driving_stretch do
    route_day
    bus_id { "TEST-0001" }
    start_time { Time.zone.parse("2026-10-19 06:00") }
    end_time { start_time + 100.minutes }
    n_trips { 2 }
  end
end
