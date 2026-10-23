# One route on one Taipei day, as written by bin/rails derived:load. Its stops,
# trips, layovers and ends are deleted with it by the database.
# == Schema Information
#
# Table name: route_days
#
#  id                  :bigint           not null, primary key
#  day                 :date             not null
#  day_note            :string
#  day_type            :string           not null
#  departure           :string           not null
#  destination         :string           not null
#  loaded_at           :timestamptz      not null
#  mrt_exits_day       :date
#  office_calendar_day :date             not null
#  public_toilets_day  :date
#  route_name          :string           not null
#  static_day          :date             not null
#  route_id            :integer          not null
#
# Indexes
#
#  index_route_days_on_route_id_and_day  (route_id,day) UNIQUE
#
class RouteDay < ApplicationRecord
  has_many :stops, class_name: "RouteDayStop", dependent: nil
  has_many :trips, dependent: nil
  has_many :layovers, dependent: nil
  has_many :ends, class_name: "RouteDayEnd", dependent: nil
end
