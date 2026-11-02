# == Schema Information
#
# Table name: layovers
#
#  id              :bigint           not null, primary key
#  end_time        :timestamptz      not null
#  go_back         :integer          not null
#  next_start_time :timestamptz      not null
#  bus_id          :string           not null
#  route_day_id    :bigint           not null
#
# Indexes
#
#  index_layovers_on_route_day_id  (route_day_id)
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
FactoryBot.define do
  # A layover of a stored day: by default TEST-0001 comes back at 08:00 on an
  # inbound trip and leaves again ten minutes later.
  factory :layover do
    route_day
    bus_id { "TEST-0001" }
    go_back { 1 }
    end_time { Time.zone.parse("#{route_day.day} 08:00") }
    next_start_time { end_time + 10.minutes }
  end
end
