require "rails_helper"

# == Schema Information
#
# Table name: route_day_published_headways
#
#  id                :bigint           not null, primary key
#  date_value        :integer          not null
#  end_minute        :integer          not null
#  high_minutes      :integer          not null
#  low_minutes       :integer          not null
#  start_minute      :integer          not null
#  path_attribute_id :integer          not null
#  route_day_id      :bigint           not null
#  route_id          :integer          not null
#
# Indexes
#
#  index_route_day_published_headways_on_day_route_value  (route_day_id,route_id,date_value)
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
RSpec.describe RouteDayPublishedHeadway, type: :model do
  it "刪路線日時一起刪" do
    headway = create(:route_day_published_headway)
    expect { headway.route_day.delete }.to change(described_class, :count).from(1).to(0)
  end

  it "路線日讀得到自己的公告班距" do
    headway = create(:route_day_published_headway)
    expect(headway.route_day.published_headways).to eq([ headway ])
  end

  it "同一個路線日可以有兩條附屬路線的同一個時段，去重是讀的時候的事" do
    headway = create(:route_day_published_headway, path_attribute_id: 157462)
    expect { create(:route_day_published_headway, route_day: headway.route_day, path_attribute_id: 157463) }.to change(described_class, :count).by(1)
  end
end
