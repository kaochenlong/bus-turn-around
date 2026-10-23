# The day type and the calendar snapshot day become required. Route days loaded
# before AddDayTypeToRouteDays have neither, and a migration cannot fill them
# in because the calendar lives under the data root, so this one stops and
# names those days until they have been loaded again.
class RequireDayTypeOnRouteDays < ActiveRecord::Migration[8.1]
  def up
    missing = select_rows(<<~SQL)
      SELECT route_id, day FROM route_days
      WHERE day_type IS NULL OR office_calendar_day IS NULL
      ORDER BY route_id, day
    SQL
    raise <<~MESSAGE if missing.any?
      這些路線日還沒有日型別：#{missing.map { |route_id, day| "#{route_id} #{day}" }.join('、')}
      先跑 bin/rails external:office_calendar YEAR=<年>，再用 bin/rails derived:load 重載這些日子，然後再跑一次 migration。
    MESSAGE

    change_column_null :route_days, :day_type, false
    change_column_null :route_days, :office_calendar_day, false
  end

  def down
    change_column_null :route_days, :day_type, true
    change_column_null :route_days, :office_calendar_day, true
  end
end
