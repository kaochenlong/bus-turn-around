# One route on one Taipei day, as written by bin/rails derived:load. Its stops,
# trips, layovers, ends, route shapes, depots, districts, rest windows, driving
# stretches and published schedule are deleted with it by the database.
# == Schema Information
#
# Table name: route_days
#
#  id                     :bigint           not null, primary key
#  day                    :date             not null
#  day_note               :string
#  day_type               :string           not null
#  departure              :string           not null
#  destination            :string           not null
#  loaded_at              :timestamptz      not null
#  member_names           :jsonb            not null
#  mrt_exits_day          :date
#  office_calendar_day    :date             not null
#  public_toilets_day     :date
#  published_schedule_day :date
#  rest_windows_loaded    :boolean          default(FALSE), not null
#  route_name             :string           not null
#  static_day             :date             not null
#  stop_districts_day     :date
#  route_id               :integer          not null
#
# Indexes
#
#  index_route_days_on_route_id_and_day  (route_id,day) UNIQUE
#
class RouteDay < ApplicationRecord
  # The route days stored before the rest windows or the published schedule existed,
  # so that the figures read from them are incomplete until they are loaded again.
  scope :needing_reload, -> { where(rest_windows_loaded: false).or(where(published_schedule_day: nil)) }

  has_many :stops, class_name: "RouteDayStop", dependent: nil
  has_many :trips, dependent: nil
  has_many :layovers, dependent: nil
  has_many :ends, class_name: "RouteDayEnd", dependent: nil
  has_many :shapes, class_name: "RouteDayShape", dependent: nil
  has_many :depots, class_name: "RouteDayDepot", dependent: nil
  has_many :districts, class_name: "RouteDayDistrict", dependent: nil
  has_many :rest_windows, class_name: "RouteDayRestWindow", dependent: nil
  has_many :driving_stretches, class_name: "RouteDayDrivingStretch", dependent: nil
  has_many :published_headways, class_name: "RouteDayPublishedHeadway", dependent: nil
  has_many :published_departures, class_name: "RouteDayPublishedDeparture", dependent: nil
end
