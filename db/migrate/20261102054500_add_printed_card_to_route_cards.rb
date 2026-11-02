# A printed month card, as in the monthly-card-pdf spec. What the list and the
# trend read stays on route_cards; the bytes get a table of their own, because
# every reader of route_cards reads whole rows and a month card page reads the
# rows of every earlier month. route_card_pdfs refers to route_cards only, so
# that bin/push-derived, which follows the foreign keys of route_days, cannot
# carry it away either.
class AddPrintedCardToRouteCards < ActiveRecord::Migration[8.1]
  def change
    change_table :route_cards, bulk: true do |t|
      t.string :pdf_sha256
      t.integer :pdf_bytes
      t.string :program_version
      t.datetime :printed_at
      t.text :revision_reason
      t.check_constraint "num_nonnulls(pdf_sha256, pdf_bytes, program_version, printed_at) IN (0, 4) AND (printed_at IS NULL OR summary IS NOT NULL)",
                         name: "route_cards_printed_complete"
    end

    create_table :route_card_pdfs do |t|
      t.references :route_card, null: false, foreign_key: true, index: { unique: true }
      t.binary :pdf, null: false
      t.timestamps
    end
  end
end
