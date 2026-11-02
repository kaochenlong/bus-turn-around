require "rails_helper"

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
RSpec.describe RouteCard, type: :model do
  it "同一條路線、同一個月、同一個版本不能有第二列" do
    card = create(:route_card)
    expect { card.dup.save! }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "同一個月可以有第二個版本" do
    card = create(:route_card)
    expect { create(:route_card, route_id: card.route_id, month: card.month, version: 2) }.to change(described_class, :count).by(1)
  end

  it "version 沒給就是 1" do
    expect(create(:route_card).version).to eq(1)
  end

  it "month 只能是當月 1 號，不是的話資料庫不收" do
    expect { create(:route_card, month: Date.new(2026, 10, 15)) }.to raise_error(ActiveRecord::StatementInvalid, /route_cards_month_first_day/)
  end

  it "summary 可以是空的：印製時才有" do
    expect(create(:route_card).summary).to be_nil
  end

  describe "印好的版本" do
    # SHA-256 of "abc" is the first example of FIPS 180-2.
    let(:abc_sha256) { "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" }

    def printed = create(:route_card, :printed, pdf: "abc")

    it "SHA-256、位元組數、程式版本、印製時間存在列上" do
      card = printed.reload
      expect([ card.pdf_sha256, card.pdf_bytes, card.program_version, card.printed_at.present? ]).to eq([ abc_sha256, 3, "abc1234", true ])
    end

    it "位元組存在 route_card_pdfs，存什麼讀回來就是什麼" do
      expect(printed.reload.route_card_pdf.pdf).to eq("abc")
    end

    it "位元組任何值都存得回來，沒有被當成文字處理" do
      bytes = (0..255).to_a.pack("C*")
      expect(create(:route_card, :printed, pdf: bytes).reload.route_card_pdf.pdf).to eq(bytes)
    end

    it "摘要跟著存：這一份印出來的數字" do
      card = create(:route_card)
      card.store_printed!(pdf: "abc", summary: { "weekdays" => 21 }, program_version: "abc1234")
      expect(card.reload.summary).to eq({ "weekdays" => 21 })
    end

    it "存第二份 PDF 失敗：印過的列不能再印" do
      card = printed
      expect { card.store_printed!(pdf: "xyz", summary: {}, program_version: "abc1234") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "寫位元組失敗時，列上也不算印過" do
      card = create(:route_card)
      allow(card).to receive(:create_route_card_pdf!).and_raise(ActiveRecord::RecordInvalid)
      suppress(ActiveRecord::RecordInvalid) { card.store_printed!(pdf: "abc", summary: {}, program_version: "abc1234") }
      expect(described_class.find(card.id)).not_to be_printed
    end

    it "存的時候可以連涵蓋與更正原因一起給：還原用的" do
      card = create(:route_card, version: 2)
      card.store_printed!(pdf: "abc", summary: {}, program_version: "abc1234", printed_at: Time.zone.parse("2026-12-01 03:00"), revision_reason: "資料重算", coverage: { "loaded_weekdays" => 1 })
      expect(card.reload.attributes.values_at("revision_reason", "coverage", "printed_at")).to eq([ "資料重算", { "loaded_weekdays" => 1 }, Time.zone.parse("2026-12-01 03:00") ])
    end

    it ".printed 只列印好的列" do
      create(:route_card)
      card = create(:route_card, :printed, month: Date.new(2026, 11, 1))
      expect(described_class.printed).to eq([ card ])
    end

    it "#printed?：印好才算" do
      expect([ create(:route_card, month: Date.new(2026, 11, 1)).printed?, printed.printed? ]).to eq([ false, true ])
    end

    it "印好的列不能再改" do
      card = described_class.find(printed.id)
      expect { card.update!(coverage: {}) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "印好的列不能刪" do
      card = described_class.find(printed.id)
      expect { card.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "印好的位元組不能再改" do
      pdf = RouteCardPdf.find(printed.route_card_pdf.id)
      expect { pdf.update!(pdf: "xyz") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "沒印的列可以改" do
      card = create(:route_card)
      expect { card.update!(coverage: { "loaded_weekdays" => 1 }) }.to change { card.reload.coverage }
    end

    it "一列只能有一份位元組，資料庫不收第二份" do
      card = printed
      expect { RouteCardPdf.create!(route_card_id: card.id, pdf: "xyz") }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    %i[pdf_sha256 pdf_bytes program_version printed_at].each do |column|
      it "印製的欄位不能只有一部分：少了 #{column} 資料庫不收" do
        values = { pdf_sha256: abc_sha256, pdf_bytes: 3, program_version: "abc1234", printed_at: Time.current, summary: {} }
        expect { create(:route_card, **values.except(column)) }.to raise_error(ActiveRecord::StatementInvalid, /route_cards_printed_complete/)
      end
    end

    it "印好的列一定有摘要，資料庫不收沒有摘要的" do
      values = { pdf_sha256: abc_sha256, pdf_bytes: 3, program_version: "abc1234", printed_at: Time.current }
      expect { create(:route_card, **values) }.to raise_error(ActiveRecord::StatementInvalid, /route_cards_printed_complete/)
    end
  end

  describe "#partial?" do
    # The rows of the spec's example "Partial or not".
    [ [ 21, 20, false ], [ 20, 18, false ], [ 21, 18, true ], [ 20, 7, true ] ].each do |calendar, loaded, partial|
      it "這個月有 #{calendar} 個平日、收到 #{loaded} 個：#{partial ? '是' : '不是'}部分月份" do
        coverage = { "calendar_weekdays" => calendar, "loaded_weekdays" => loaded }
        expect(build(:route_card, coverage:).partial?).to be(partial)
      end
    end
  end

  describe ".newest" do
    it "同一個月取版本最大的那一列" do
      first = create(:route_card)
      second = create(:route_card, route_id: first.route_id, month: first.month, version: 2)
      expect(described_class.newest(first.route_id, first.month)).to eq(second)
    end

    it "別的月份與別的路線不算" do
      create(:route_card, route_id: 9001, month: Date.new(2026, 9, 1))
      create(:route_card, route_id: 9100, month: Date.new(2026, 10, 1))
      expect(described_class.newest(9001, Date.new(2026, 10, 1))).to be_nil
    end
  end

  describe "#identity" do
    it "路線、月份與版本：15373/2026-11/2" do
      expect(build(:route_card, route_id: 15373, month: Date.new(2026, 11, 1), version: 2).identity).to eq("15373/2026-11/2")
    end
  end

  describe "#month_days" do
    it "當月每一天" do
      days = build(:route_card, month: Date.new(2026, 10, 1)).month_days
      expect([ days.first, days.last, days.count ]).to eq([ Date.new(2026, 10, 1), Date.new(2026, 10, 31), 31 ])
    end
  end
end
