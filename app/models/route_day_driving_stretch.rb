# One continuous driving stretch of a vehicle on a route day, as defined by the
# layover-metrics spec: trips joined where no layover between them reaches the
# minimum rest. It describes a vehicle, not a driver, and carries a plate, so
# no page shows it row by row.
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
class RouteDayDrivingStretch < ApplicationRecord
  belongs_to :route_day
end
