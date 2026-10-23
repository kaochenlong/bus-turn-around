FactoryBot.define do
  # A toilet stored for an end: by default the nearest toilet of the fixture's
  # 戊站 end.
  factory :route_day_end_toilet do
    route_day_end
    name { "戊站公園-男廁" }
    category { "公園" }
    address { "臺北市測試區戊路2號" }
    latitude { 25.062686 }
    longitude { 121.5003 }
    meters { 251.7 }
  end
end
