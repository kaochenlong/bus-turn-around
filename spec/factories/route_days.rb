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
#  route_name          :string           not null
#  static_day          :date             not null
#  route_id            :integer          not null
#
# Indexes
#
#  index_route_days_on_route_id_and_day  (route_id,day) UNIQUE
#
FactoryBot.define do
  # A stored day of the fixture route 9001. It is a weekday of the office
  # calendar unless a test gives another day type; the day type does not
  # follow the date.
  factory :route_day do
    route_id { 9001 }
    day { Date.new(2026, 10, 19) }
    route_name { "測試幹線" }
    departure { "甲站" }
    destination { "戊站" }
    static_day { day }
    loaded_at { Time.current }
    day_type { "weekday" }
    office_calendar_day { Date.new(2026, 10, 19) }
  end
end
