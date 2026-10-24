# The route shape of each route day: per direction, the line 臺北市公共運輸處
# registers for the route, the time the office last updated it and its points
# as [latitude, longitude] pairs in their original order, deleted with the
# route day. Days loaded before this have no shapes until they are loaded
# again; nothing is filled in here, because the static snapshots live under
# the data root.
class CreateRouteDayShapes < ActiveRecord::Migration[8.1]
  def change
    create_table :route_day_shapes do |t|
      t.references :route_day, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :go_back, null: false
      t.timestamptz :shape_updated_at, null: false
      t.jsonb :points, null: false
      t.index [ :route_day_id, :go_back ], unique: true
    end
  end
end
