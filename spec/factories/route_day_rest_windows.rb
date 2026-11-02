# == Schema Information
#
# Table name: route_day_rest_windows
#
#  id                      :bigint           not null, primary key
#  credit_minutes          :float            not null
#  end_time                :timestamptz      not null
#  flagged                 :boolean          not null
#  longest_layover_minutes :float            not null
#  n_trips                 :integer          not null
#  over_daily_driving      :boolean          not null
#  rule                    :string           not null
#  start_time              :timestamptz      not null
#  bus_id                  :string           not null
#  route_day_id            :bigint           not null
#
# Indexes
#
#  index_route_day_rest_windows_on_day_rule_bus_start  (route_day_id,rule,bus_id,start_time) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
FactoryBot.define do
  # One window of a stored day: by default a four-hour window of TEST-0001 from
  # 06:00 to 10:30 with 3 trips, a rest credit and longest layover of 20
  # minutes, flagged, on a vehicle under the daily driving limit.
  factory :route_day_rest_window do
    route_day
    bus_id { "TEST-0001" }
    rule { "four_hours" }
    start_time { Time.zone.parse("2026-10-19 06:00") }
    end_time { start_time + 270.minutes }
    n_trips { 3 }
    credit_minutes { 20.0 }
    longest_layover_minutes { 20.0 }
    flagged { true }
    over_daily_driving { false }
  end
end
