# A route's month card, as in the monthly-card spec: one row per route, month
# and version. The production host has neither the raw files nor the office
# calendar, so which days a month covers is worked out where they are and stored
# here. It does not reference route_days, so that bin/push-derived, which follows
# the foreign keys, cannot carry it away when it replaces the derived tables: a
# printed card cannot be recomputed into the same card.
class CreateRouteCards < ActiveRecord::Migration[8.1]
  def change
    create_table :route_cards do |t|
      t.integer :route_id, null: false
      t.date :month, null: false
      t.integer :version, null: false, default: 1
      t.jsonb :coverage, null: false
      t.jsonb :summary
      t.timestamps
      t.index [ :route_id, :month, :version ], unique: true
      t.check_constraint "extract(day from month) = 1", name: "route_cards_month_first_day"
    end
  end
end
