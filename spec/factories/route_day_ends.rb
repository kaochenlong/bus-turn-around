FactoryBot.define do
  # One end of a stored day: by default direction 0 of route 9001, a stopping
  # end at 戊站 located as on the fixture day.
  factory :route_day_end do
    route_day
    go_back { 0 }
    end_seq { 4 }
    end_stop_name { "戊站" }
    end_latitude { 25.06 }
    end_longitude { 121.5 }
    location_source { "standstill" }
    latitude { 25.060422 }
    longitude { 121.5003 }
    n_layovers { 10 }
    n_located_layovers { 3 }
    n_standstill_records { 29 }
    end_stop_meters { 55.8 }

    # A stopping end with no standstill report that day.
    trait :unlocated do
      location_source { nil }
      latitude { nil }
      longitude { nil }
      n_located_layovers { nil }
      n_standstill_records { 0 }
      end_stop_meters { nil }
    end
  end
end
