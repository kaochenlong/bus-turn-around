# == Schema Information
#
# Table name: route_day_end_cells
#
#  id               :bigint           not null, primary key
#  cell_latitude    :float            not null
#  cell_longitude   :float            not null
#  n_buses          :integer          not null
#  n_layovers       :integer          not null
#  n_records        :integer          not null
#  route_day_end_id :bigint           not null
#
# Indexes
#
#  idx_on_route_day_end_id_cell_latitude_cell_longitud_cd42233ab5  (route_day_end_id,cell_latitude,cell_longitude) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_end_id => route_day_ends.id) ON DELETE => cascade
#
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
