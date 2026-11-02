# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthCardBufferComponent, type: :component do
  let(:route_card) { create(:route_card) }
  let(:month_card) { RoutePage::MonthCard.new(route_card) }
  let(:bound) { RoutePage::BufferTrade::Bound }
  let(:peak) { RoutePage::BufferTrade::Peak }

  # A trade for `minutes` with the figures given, standing in for RoutePage::BufferTrade.
  def trade(minutes, achieved: 0.57, lower: 2.0, upper: 9.9, peak_lower: peak.new(hour: 19, vehicles: 0.3), peak_upper: peak.new(hour: 19, vehicles: 1.0))
    instance_double(RoutePage::BufferTrade, minutes:, achieved_share: achieved, vehicle_hours: bound.new(lower:, upper:), peak: bound.new(lower: peak_lower, upper: peak_upper),
                                            n_days: 7, n_trips: 1134, n_stopping_layovers: 276)
  end

  def render_block(*trades)
    allow(month_card).to receive(:buffer_trades).and_return(trades)
    render_inline(described_class.new(month_card:))
  end

  def row(minutes) = page.find("tr[data-hold='#{minutes}']").all("td").map(&:text)

  it "15 分鐘那一列：已經停得到、補足、都多留與最忙的小時（規格的例子）" do
    render_block(trade(15))
    expect(row(15)).to eq([ "15 分鐘", "57%", "2.0", "9.9", "0.3–1.0 台（19 時）" ])
  end

  it "兩個上下界最忙的小時不同：各寫各的小時" do
    render_block(trade(15, peak_lower: peak.new(hour: 18, vehicles: 0.3)))
    expect(row(15).last).to eq("0.3 台（18 時）–1.0 台（19 時）")
  end

  it "10、15、20 分鐘各一列" do
    render_block(trade(10), trade(15), trade(20))
    expect(page.all("tr[data-hold]").map { it["data-hold"] }).to eq(%w[10 15 20])
  end

  it "說明寫幾個平日、幾趟、量得到的幾次" do
    render_block(trade(15))
    expect(page.find("[data-buffer-lead]").text).to include("7 個平日總共跑了 1,134 趟，在停車那一端量得到車停多久的有 276 次")
  end

  it "停車端沒有折返停留：那些格子是 —" do
    empty = instance_double(RoutePage::BufferTrade, minutes: 15, achieved_share: nil, vehicle_hours: nil, peak: nil, n_days: 7, n_trips: 3, n_stopping_layovers: 0)
    render_block(empty)
    expect(row(15)).to eq([ "15 分鐘", "—", "—", "—", "—" ])
  end

  it "區塊標記是 buffer" do
    render_block(trade(15))
    expect(page).to have_css("section[data-card-section='buffer']")
  end
end
