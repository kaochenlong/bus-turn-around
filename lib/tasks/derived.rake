namespace :derived do
  desc "把一條路線的台北日寫進衍生表：ROUTE=15373 DAY=2026-10-19，或 FROM=… TO=…；資料根目錄給 TURNAROUND_DATA"
  task load: :environment do
    exit DerivedLoadCommand.new(ENV.to_h).run
  end
end
