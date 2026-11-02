require "rails_helper"
require_relative "../support/duckdb"

# The fixture's office calendar is the real one of 2026, so the numbers of
# weekdays and holidays are those of the real October and November.
RSpec.describe RouteCardCoverage, type: :model do
  let(:october) { Date.new(2026, 10, 1) }
  let(:skip_reason) { "薔琵颱風，公運處公告減班停駛" }
  let(:derived_days) { DerivedDays.new(first_day: Date.new(2026, 10, 19), skipped_days: { Date.new(2026, 10, 23) => skip_reason, Date.new(2026, 10, 24) => skip_reason }) }
  let(:after_october) { Time.zone.parse("2026-11-02 09:00") }

  # Stands in for RawDayCheck: the days given fail it, every other day passes.
  def raw_check(*failing)
    Class.new do
      define_singleton_method(:check!) do |data_root:, day:| # rubocop:disable Lint/UnusedBlockArgument
        raise RawDayCheck::Failure, "缺原始檔" if failing.include?(day)
      end
    end
  end

  def coverage(month: october, days: derived_days, now: after_october, check: raw_check, route_id: 15373)
    described_class.new(route_id:, month:, data_root: DuckdbHelpers::FIXTURE_DATA, days:, now:, check:)
  end

  def store(*days, route_id: 15373) = days.each { create(:route_day, route_id:, day: it) }

  # The stored days of the spec's scenario "A month with every kind of missing day".
  def store_october
    store(*(Date.new(2026, 10, 19)..Date.new(2026, 10, 31)).reject { [ 23, 24, 30 ].include?(it.day) })
  end

  describe "每一種少的日子都有的月份（規格的情境）" do
    subject(:october_coverage) { coverage(check: raw_check(Date.new(2026, 10, 30))) }

    before { store_october }

    it "到齊，也是部分月份" do
      expect([ october_coverage.ready?, october_coverage.partial? ]).to eq([ true, true ])
    end

    it "這個月 20 個平日、11 個假日，載入 7 個平日、3 個假日" do
      expect(october_coverage.to_h.values_at("calendar_weekdays", "calendar_holidays", "loaded_weekdays", "loaded_holidays")).to eq([ 20, 11, 7, 3 ])
    end

    it "少的日子三段，相鄰而且原因相同的併起來" do
      missing = october_coverage.to_h.fetch("missing").map { it.values_at("from", "to", "reason") }
      expect(missing).to eq([ [ "2026-10-01", "2026-10-18", "還沒開始收資料" ], [ "2026-10-23", "2026-10-24", skip_reason ], [ "2026-10-30", "2026-10-30", "原始檔不齊" ] ])
    end

    it "一段裡日型別都一樣才寫，混著的是空的" do
      expect(october_coverage.to_h.fetch("missing").map { it["day_type"] }).to eq([ nil, nil, "weekday" ])
    end

    it "存進 jsonb 再讀回來是同一份：鍵與日期都是字串" do
      card = create(:route_card, route_id: 15373, coverage: october_coverage.to_h)
      expect(card.reload.coverage).to eq(october_coverage.to_h)
    end
  end

  describe "還在等的日子" do
    it "原始檔齊全、沒有跳過、也還沒載入：在等，不算到齊" do
      store_october
      result = coverage(check: raw_check)
      expect([ result.ready?, result.waiting_days ]).to eq([ false, [ Date.new(2026, 10, 30) ] ])
    end

    it "11-30 的讀檔視窗到 12-01 02:00，12-01 01:30 還在等" do
      store(*(Date.new(2026, 11, 1)..Date.new(2026, 11, 29)))
      result = coverage(month: Date.new(2026, 11, 1), now: Time.zone.parse("2026-12-01 01:30"))
      expect([ result.ready?, result.waiting_days ]).to eq([ false, [ Date.new(2026, 11, 30) ] ])
    end

    it "讀檔視窗還沒結束時，原始檔檢查不過也只是在等，不算原始檔不齊" do
      store(*(Date.new(2026, 11, 1)..Date.new(2026, 11, 29)))
      result = coverage(month: Date.new(2026, 11, 1), now: Time.zone.parse("2026-12-01 01:30"), check: raw_check(Date.new(2026, 11, 30)))
      expect([ result.waiting_days, result.to_h.fetch("missing") ]).to eq([ [ Date.new(2026, 11, 30) ], [] ])
    end

    it "12-01 02:00 視窗結束：11-30 檢查不過就是少的日子，到齊" do
      store(*(Date.new(2026, 11, 1)..Date.new(2026, 11, 29)))
      result = coverage(month: Date.new(2026, 11, 1), now: Time.zone.parse("2026-12-01 02:00"), check: raw_check(Date.new(2026, 11, 30)))
      expect([ result.ready?, result.to_h.fetch("missing").map { it["reason"] } ]).to eq([ true, [ "原始檔不齊" ] ])
    end

    it "還沒到的月份每一天都在等" do
      expect(coverage(month: Date.new(2026, 12, 1)).waiting_days.size).to eq(31)
    end
  end

  describe "分類的先後" do
    it "已載入優先：跳過名單裡的日子有存，就算載入" do
      store(Date.new(2026, 10, 23))
      expect(coverage.to_h.fetch("missing").map { it["from"] }).not_to include("2026-10-23")
    end

    it "早於 first_day 不查原始檔" do
      store_october
      check = raw_check(Date.new(2026, 10, 1))
      expect(coverage(check:).to_h.fetch("missing").first.values_at("from", "reason")).to eq([ "2026-10-01", "還沒開始收資料" ])
    end

    it "別條路線存的日子不算" do
      store_october
      store(Date.new(2026, 10, 23), route_id: 9001)
      expect(coverage.to_h.fetch("missing").map { it["from"] }).to include("2026-10-23")
    end
  end

  describe "併段" do
    it "原因相同但不相鄰的兩天不併" do
      store(*(Date.new(2026, 10, 19)..Date.new(2026, 10, 31)).reject { [ 20, 22 ].include?(it.day) })
      days = DerivedDays.new(first_day: Date.new(2026, 10, 19), skipped_days: {})
      missing = coverage(check: raw_check(Date.new(2026, 10, 20), Date.new(2026, 10, 22)), days:).to_h.fetch("missing")
      expect(missing.map { it.values_at("from", "to") }).to eq([ [ "2026-10-01", "2026-10-18" ], [ "2026-10-20", "2026-10-20" ], [ "2026-10-22", "2026-10-22" ] ])
    end

    it "相鄰但原因不同的兩天不併" do
      store(*(Date.new(2026, 10, 19)..Date.new(2026, 10, 31)).reject { [ 24, 25 ].include?(it.day) })
      days = DerivedDays.new(first_day: Date.new(2026, 10, 19), skipped_days: { Date.new(2026, 10, 24) => skip_reason })
      expect(coverage(check: raw_check(Date.new(2026, 10, 25)), days:).to_h.fetch("missing").map { it["reason"] }).to eq([ "還沒開始收資料", skip_reason, "原始檔不齊" ])
    end
  end
end
