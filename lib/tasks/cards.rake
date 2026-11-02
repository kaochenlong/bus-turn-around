namespace :cards do
  desc "算一條路線一個月的涵蓋並寫進 route_cards：ROUTE=15373 MONTH=2026-10；資料根目錄給 TURNAROUND_DATA"
  task prepare: :environment do
    exit RouteCardPrepareCommand.new(ENV.to_h).run
  end
end
