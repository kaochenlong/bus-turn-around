# A cell of standstill reports at an end on that day, named by its south-west
# corner; only cells where at least three vehicles stood are stored.
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
class RouteDayEndCell < ApplicationRecord
  belongs_to :route_day_end
end
