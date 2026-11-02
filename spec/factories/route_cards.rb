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
FactoryBot.define do
  # The card of route 9001 for 2026-10: 20 calendar weekdays and 11 holidays, of
  # which 18 and 5 are loaded, nothing missing to report by default and nothing
  # printed yet.
  factory :route_card do
    route_id { 9001 }
    month { Date.new(2026, 10, 1) }
    coverage { { "calendar_weekdays" => 20, "calendar_holidays" => 11, "loaded_weekdays" => 18, "loaded_holidays" => 5, "missing" => [] } }

    # A printed version, through what the printing command calls.
    trait :printed do
      transient do
        pdf { "%PDF-1.7 測試用的 PDF" }
      end

      after(:create) do |card, context|
        card.store_printed!(pdf: context.pdf, summary: card.summary || { "weekdays" => 18 }, program_version: "abc1234")
      end
    end
  end
end
