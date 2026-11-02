# A route's card for one month, as in the monthly-card spec. coverage says which
# days of the month it covers and why others are missing, and is worked out where
# the raw files are, because the production host has none. summary holds the
# figures of the printed card, written when it is printed.
# == Schema Information
#
# Table name: route_cards
#
#  id              :bigint           not null, primary key
#  coverage        :jsonb            not null
#  month           :date             not null
#  pdf_bytes       :integer
#  pdf_sha256      :string
#  printed_at      :datetime
#  program_version :string
#  revision_reason :text
#  summary         :jsonb
#  version         :integer          default(1), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  route_id        :integer          not null
#
# Indexes
#
#  index_route_cards_on_route_id_and_month_and_version  (route_id,month,version) UNIQUE
#
class RouteCard < ApplicationRecord
  # A month is partial when under this share of its weekdays was loaded: a day or
  # two missing does not change the month's figures, but a reader has to be able
  # to tell a few days from a whole month.
  FULL_MONTH_PERCENT = 90

  has_one :route_card_pdf

  # The versions with a printed file. What the list and the download go by.
  scope :printed, -> { where.not(printed_at: nil) }

  # The version the page shows, nil when the month has no card.
  def self.newest(route_id, month) = where(route_id:, month:).order(version: :desc).first

  # Compared as whole numbers, so exactly 90% is not partial.
  def self.partial?(coverage) = coverage.fetch("loaded_weekdays") * 100 < coverage.fetch("calendar_weekdays") * FULL_MONTH_PERCENT

  def partial? = self.class.partial?(coverage)

  # Every day of the month.
  def month_days = month..month.end_of_month

  # The month as an address and a file name write it.
  def year_month = month.strftime("%Y-%m")

  # Which card this is, as the month card page says of itself and the printer checks.
  def identity = "#{route_id}/#{year_month}/#{version}"

  # Whether this version has a printed file, whatever is assigned but not saved.
  def printed? = printed_at_in_database.present?

  # A printed version gets cited, so it never changes: a correction is a new version.
  def readonly? = super || printed?

  # Stores a printed file with what the page said when it was printed. attributes
  # are what a restore brings along. The row and the bytes go together or not at all.
  def store_printed!(pdf:, summary:, program_version:, printed_at: Time.current, **attributes)
    transaction do
      update!(pdf_sha256: Digest::SHA256.hexdigest(pdf), pdf_bytes: pdf.bytesize, summary:, program_version:, printed_at:, **attributes)
      create_route_card_pdf!(pdf:)
    end
  end
end
