require "rails_helper"

RSpec.describe RoutePage::CardTrend, type: :model do
  let(:october) { Date.new(2026, 10, 1) }
  let(:september) { Date.new(2026, 9, 1) }

  def card_for(month, route_id: 9001, **attributes) = create(:route_card, route_id:, month:, **attributes)

  def trend(route_card) = described_class.new(RoutePage::MonthCard.new(route_card))

  # A stored weekday with a stop at the end of direction 1 and one layover per minutes given.
  def store_weekday(day, *minutes, route_id: 9001)
    create(:route_day, route_id:, day: Date.iso8601(day), rest_windows_loaded: true, published_schedule_day: Date.iso8601(day)).tap do |route_day|
      route_day.stops.create!(go_back: 1, seq: 5, stop_name: "甲站")
      minutes.each_with_index { |length, index| add_layover(route_day, length, index) }
    end
  end

  def add_layover(route_day, minutes, index)
    end_time = Time.zone.parse("#{route_day.day} 08:00")
    create(:layover, route_day:, bus_id: "TEST-#{index}", end_time:, next_start_time: end_time + minutes.minutes)
  end

  describe "#rows" do
    it "只有一份：一列" do
      expect(trend(card_for(october)).rows.map(&:month)).to eq([ october ])
    end

    it "有上一份：舊的在前" do
      card_for(september)
      expect(trend(card_for(october)).rows.map(&:month)).to eq([ september, october ])
    end

    it "這個月之後的月份不列" do
      card_for(Date.new(2026, 11, 1))
      expect(trend(card_for(october)).rows.map(&:month)).to eq([ october ])
    end

    it "別條路線的月份不列" do
      card_for(september, route_id: 9100)
      expect(trend(card_for(october)).rows.map(&:month)).to eq([ october ])
    end

    it "同一個月多個版本只有一列" do
      card_for(september)
      card_for(september, version: 2)
      expect(trend(card_for(october)).rows.map(&:month)).to eq([ september, october ])
    end

    it "部分月份標出來" do
      card_for(september, coverage: { "calendar_weekdays" => 20, "loaded_weekdays" => 7 })
      expect(trend(card_for(october)).rows.map(&:partial)).to eq([ true, false ])
    end
  end

  describe "一列的數字是現在重算的" do
    subject(:row) { trend(card_for(october)).rows.sole }

    before do
      store_weekday("2026-10-19", 10, 10, 20, 20)
      store_weekday("2026-10-20", 10, 20, 20, 20)
    end

    it "平日天數" do
      expect(row.weekdays).to eq(2)
    end

    it "每個停車端的比例、逐日範圍與 p10" do
      figures = row.ends.find { it.go_back == 1 }
      expect(figures.to_h).to eq(go_back: 1, stop_name: "甲站", short_share: 3.0 / 8, day_low: 0.25, day_high: 0.5, p10: 10.0)
    end

    it "連續 4 與 6 小時的比例" do
      route_day = RouteDay.find_by!(day: Date.new(2026, 10, 19))
      [ [ "TEST-0001", true ], [ "TEST-0002", false ] ].each { |bus_id, flagged| create(:route_day_rest_window, route_day:, bus_id:, flagged:) }
      create(:route_day_rest_window, route_day:, rule: "six_hours", flagged: true)
      expect([ row.four_hours_share, row.six_hours_share ]).to eq([ 0.5, 1.0 ])
    end

    it "早尖峰路上的車：下界最小、上午開始的時段，取整數" do
      RouteDay.find_each { create(:route_day_published_headway, route_day: it, date_value: it.day.wday + 1, start_minute: 360, end_minute: 420) }
      create(:trip, route_day: RouteDay.first, start_time: Time.zone.parse("2026-10-19 06:00"), end_time: Time.zone.parse("2026-10-19 07:00"))
      expect(row.morning_on_road).to eq(1)
    end

    it "沒有時段：早尖峰路上的車是空的" do
      expect(row.morning_on_road).to be_nil
    end
  end

  describe "#previous" do
    it "上個月有卡：那個月的月卡" do
      card_for(september)
      expect(trend(card_for(october)).previous.month).to eq(september)
    end

    it "上個月沒有卡：nil，就算更早的月份有" do
      card_for(Date.new(2026, 8, 1))
      expect(trend(card_for(october)).previous).to be_nil
    end
  end

  describe "#first_card?" do
    it "只有一份：是" do
      expect(trend(card_for(october))).to be_first_card
    end

    it "有更早的月份：不是" do
      card_for(Date.new(2026, 8, 1))
      expect(trend(card_for(october))).not_to be_first_card
    end
  end

  describe "#differing_months" do
    before { store_weekday("2026-09-21", 10, 20) }

    def recomputed = RoutePage::MonthCard.new(RouteCard.find_by!(month: september)).summary

    it "舊月份存的 summary 跟重算的不同：點名那個月" do
      card = card_for(september)
      card.update!(summary: recomputed.merge("short_share" => { "1" => 40.0 }))
      expect(trend(card_for(october)).differing_months).to eq([ september ])
    end

    it "存的跟重算的相同：沒有" do
      card = card_for(september)
      card.update!(summary: recomputed)
      expect(trend(card_for(october)).differing_months).to eq([])
    end

    it "舊月份沒有存 summary：沒有" do
      card_for(september)
      expect(trend(card_for(october)).differing_months).to eq([])
    end

    it "這個月自己不比" do
      card = card_for(september)
      card.update!(summary: recomputed.merge("weekdays" => 99))
      expect(trend(card).differing_months).to eq([])
    end
  end
end
