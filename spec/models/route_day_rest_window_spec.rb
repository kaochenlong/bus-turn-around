require "rails_helper"

# == Schema Information
#
# Table name: route_day_rest_windows
#
#  id                      :bigint           not null, primary key
#  credit_minutes          :float            not null
#  end_time                :timestamptz      not null
#  flagged                 :boolean          not null
#  longest_layover_minutes :float            not null
#  n_trips                 :integer          not null
#  over_daily_driving      :boolean          not null
#  rule                    :string           not null
#  start_time              :timestamptz      not null
#  bus_id                  :string           not null
#  route_day_id            :bigint           not null
#
# Indexes
#
#  index_route_day_rest_windows_on_day_rule_bus_start  (route_day_id,rule,bus_id,start_time) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
RSpec.describe RouteDayRestWindow, type: :model do
  it "同一個路線日、規則、車牌與起點不能有第二列" do
    window = create(:route_day_rest_window)
    copy = window.dup
    expect { copy.save! }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "同一台車同一個起點，兩條規則各一列" do
    window = create(:route_day_rest_window, rule: "four_hours")
    expect { create(:route_day_rest_window, route_day: window.route_day, rule: "six_hours") }.to change(described_class, :count).by(1)
  end

  it "規則只能是 four_hours 或 six_hours，打錯字寫不進去" do
    expect { create(:route_day_rest_window, rule: "five_hours") }.to raise_error(ActiveRecord::StatementInvalid, /route_day_rest_windows_rule/)
  end

  it "刪路線日時一起刪" do
    window = create(:route_day_rest_window)
    expect { window.route_day.delete }.to change(described_class, :count).from(1).to(0)
  end

  it "路線日讀得到自己的視窗" do
    window = create(:route_day_rest_window)
    expect(window.route_day.rest_windows).to eq([ window ])
  end
end
