require "rails_helper"

# == Schema Information
#
# Table name: route_days
#
#  id                     :bigint           not null, primary key
#  day                    :date             not null
#  day_note               :string
#  day_type               :string           not null
#  departure              :string           not null
#  destination            :string           not null
#  loaded_at              :timestamptz      not null
#  member_names           :jsonb            not null
#  mrt_exits_day          :date
#  office_calendar_day    :date             not null
#  public_toilets_day     :date
#  published_schedule_day :date
#  rest_windows_loaded    :boolean          default(FALSE), not null
#  route_name             :string           not null
#  static_day             :date             not null
#  stop_districts_day     :date
#  route_id               :integer          not null
#
# Indexes
#
#  index_route_days_on_route_id_and_day  (route_id,day) UNIQUE
#
RSpec.describe RouteDay, type: :model do
  it "還沒重算過的路線日，rest_windows_loaded 是 false" do
    expect(create(:route_day).rest_windows_loaded).to be(false)
  end

  it "還沒重算過的路線日，published_schedule_day 是空的" do
    expect(create(:route_day).published_schedule_day).to be_nil
  end

  def create_route_day(day: Date.new(2026, 10, 19))
    create(:route_day, day:)
  end

  # One stop, one trip with one count, and one layover on the route day.
  def fill(route_day)
    route_day.stops.create!(go_back: 0, seq: 0, stop_name: "甲站")
    trip = route_day.trips.create!(bus_id: "TEST-0001", path_attribute_id: 9001, go_back: 0, band: "other",
                                   start_time: Time.zone.parse("2026-10-19 06:00"), end_time: Time.zone.parse("2026-10-19 06:50"),
                                   first_seq: 0, last_seq: 4, n_events: 10, n_stops_observed: 5, completeness: "complete",
                                   start_from_arrival: false, end_from_departure: false)
    trip.trip_stop_counts.create!(seq: 0, on_board: 3)
    route_day.layovers.create!(bus_id: "TEST-0001", go_back: 0, end_time: trip.end_time, next_start_time: trip.end_time + 10.minutes)
  end

  def row_counts = [ RouteDayStop, Trip, TripStopCount, Layover ].map(&:count)

  it "刪掉一天時，那一天的站序、趟次、趟次站人數與折返停留都跟著刪掉" do
    route_day = create_route_day.tap { fill(it) }
    expect { route_day.delete }.to change { row_counts }.from([ 1, 1, 1, 1 ]).to([ 0, 0, 0, 0 ])
  end

  it "同一路線同一天只能有一列" do
    create_route_day
    expect { create_route_day }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "刪掉一天時，那一天的調度站跟著刪掉" do
    route_day = create_route_day.tap { create(:route_day_depot, route_day: it) }
    expect { route_day.delete }.to change(RouteDayDepot, :count).from(1).to(0)
  end

  it "同一天同一個調度站只能有一列" do
    route_day = create_route_day.tap { create(:route_day_depot, route_day: it) }
    expect { create(:route_day_depot, route_day:) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "沒給 route_id 的站序與趟次，預設屬於路線日的路線" do
    route_day = create_route_day.tap { fill(it) }
    expect([ route_day.stops.sole.route_id, route_day.trips.sole.route_id ]).to eq([ 9001, 9001 ])
  end

  it "同一天同方向同站序，兩條路線各一列可以，同一條路線兩列不行" do
    route_day = create_route_day
    route_day.stops.create!(route_id: 9001, go_back: 0, seq: 0, stop_name: "甲站")
    route_day.stops.create!(route_id: 9050, go_back: 0, seq: 0, stop_name: "甲站")
    expect { route_day.stops.create!(route_id: 9050, go_back: 0, seq: 0, stop_name: "甲站") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  %w[day_type office_calendar_day].each do |column|
    it "#{column} 是空的路線日，資料庫不收" do
      expect { create(:route_day, column => nil) }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe ".needing_reload" do
    def stored(**attributes) = create(:route_day, day: Date.new(2026, 11, 1) + RouteDay.count, rest_windows_loaded: true, published_schedule_day: Date.new(2026, 11, 1), **attributes)

    it "視窗或公告還沒載入的路線日都算，兩個都載入的不算" do
      windows, schedule = stored(rest_windows_loaded: false), stored(published_schedule_day: nil)
      stored
      expect(described_class.needing_reload).to contain_exactly(windows, schedule)
    end
  end
end
