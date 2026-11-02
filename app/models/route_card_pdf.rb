# The bytes of a printed month card, as in the monthly-card-pdf spec: in a table of
# their own, so that reading a route card never reads them and only the download
# does. They are what gets cited, so they never change.
# == Schema Information
#
# Table name: route_card_pdfs
#
#  id            :bigint           not null, primary key
#  pdf           :binary           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  route_card_id :bigint           not null
#
# Indexes
#
#  index_route_card_pdfs_on_route_card_id  (route_card_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_card_id => route_cards.id)
#
class RouteCardPdf < ApplicationRecord
  belongs_to :route_card

  def readonly? = super || persisted?
end
