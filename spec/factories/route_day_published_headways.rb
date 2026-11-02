# == Schema Information
#
# Table name: route_day_published_headways
#
#  id                :bigint           not null, primary key
#  date_value        :integer          not null
#  end_minute        :integer          not null
#  high_minutes      :integer          not null
#  low_minutes       :integer          not null
#  start_minute      :integer          not null
#  path_attribute_id :integer          not null
#  route_day_id      :bigint           not null
#  route_id          :integer          not null
#
# Indexes
#
#  index_route_day_published_headways_on_day_route_value  (route_day_id,route_id,date_value)
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
FactoryBot.define do
  # One published period of a stored day: by default a Monday's 06:00 to 08:00
  # of route 9001, with a headway of 5 to 10 minutes.
  factory :route_day_published_headway do
    route_day
    route_id { 9001 }
    path_attribute_id { route_id }
    date_value { 2 }
    start_minute { 360 }
    end_minute { 480 }
    low_minutes { 5 }
    high_minutes { 10 }
  end
end
