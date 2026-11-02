require "rails_helper"

# == Schema Information
#
# Table name: route_day_driving_stretches
#
#  id           :bigint           not null, primary key
#  end_time     :timestamptz      not null
#  n_trips      :integer          not null
#  start_time   :timestamptz      not null
#  bus_id       :string           not null
#  route_day_id :bigint           not null
#
# Indexes
#
#  index_route_day_driving_stretches_on_day_bus_start  (route_day_id,bus_id,start_time) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
RSpec.describe RouteDayDrivingStretch, type: :model do
  it "同一個路線日、車牌與起點不能有第二列" do
    stretch = create(:route_day_driving_stretch)
    copy = stretch.dup
    expect { copy.save! }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "刪路線日時一起刪" do
    stretch = create(:route_day_driving_stretch)
    expect { stretch.route_day.delete }.to change(described_class, :count).from(1).to(0)
  end

  it "路線日讀得到自己的連續行駛段" do
    stretch = create(:route_day_driving_stretch)
    expect(stretch.route_day.driving_stretches).to eq([ stretch ])
  end
end
