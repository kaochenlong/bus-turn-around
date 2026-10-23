FactoryBot.define do
  # A standstill cell of an end: by default the fixture's one cell at 戊站.
  factory :route_day_end_cell do
    route_day_end
    cell_latitude { 25.0604 }
    cell_longitude { 121.5002 }
    n_records { 25 }
    n_buses { 3 }
    n_layovers { 3 }
  end
end
