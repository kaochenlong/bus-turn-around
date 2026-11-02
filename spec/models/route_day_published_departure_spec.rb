require "rails_helper"

# == Schema Information
#
# Table name: route_day_published_departures
#
#  id                :bigint           not null, primary key
#  date_value        :integer          not null
#  minute            :integer          not null
#  path_attribute_id :integer          not null
#  route_day_id      :bigint           not null
#  route_id          :integer          not null
#
# Indexes
#
#  index_route_day_published_departures_on_day_route_value  (route_day_id,route_id,date_value)
#
# Foreign Keys
#
#  fk_rails_...  (route_day_id => route_days.id) ON DELETE => cascade
#
RSpec.describe RouteDayPublishedDeparture, type: :model do
  it "刪路線日時一起刪" do
    departure = create(:route_day_published_departure)
    expect { departure.route_day.delete }.to change(described_class, :count).from(1).to(0)
  end

  it "路線日讀得到自己的定時班次" do
    departure = create(:route_day_published_departure)
    expect(departure.route_day.published_departures).to eq([ departure ])
  end
end
