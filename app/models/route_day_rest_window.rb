# One window of a rest rule on a route day, as defined by the layover-metrics
# spec: the rule, the vehicle, the window's start and end, its trips, the rest
# credit, the longest layover, whether the rule flags it, and whether the
# vehicle drove over the daily limit that day. It describes a vehicle, not a
# driver, and carries a plate, so no page shows it row by row.
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
class RouteDayRestWindow < ApplicationRecord
  belongs_to :route_day
end
