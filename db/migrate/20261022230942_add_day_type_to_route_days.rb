# Each route day's day type (weekday or holiday) and note from the office
# calendar, and the calendar snapshot they came from. Days loaded before this
# stay empty until they are loaded again; the next migration then makes the
# day type and the snapshot day required.
class AddDayTypeToRouteDays < ActiveRecord::Migration[8.1]
  def change
    change_table :route_days, bulk: true do |t|
      t.string :day_type
      t.string :day_note
      t.date :office_calendar_day
    end
  end
end
